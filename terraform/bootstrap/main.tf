# Run ONCE with local state from your laptop (admin credentials).
# Creates: KMS key, Terraform state bucket, audit bucket, ECR repos, GitHub OIDC provider + CI deploy role.
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.80" }
  }
}

provider "aws" { region = var.region }

variable "region" { default = "ap-south-1" }
variable "project" { default = "securedeploy" }
variable "github_repo" {
  description = "owner/repo, e.g. alice/securedeploy"
  type        = string
}

data "aws_caller_identity" "me" {}
locals { acct = data.aws_caller_identity.me.account_id }

resource "aws_kms_key" "main" {
  description         = "${var.project} state/audit/ecr key"
  enable_key_rotation = true
}
resource "aws_kms_alias" "main" {
  name          = "alias/${var.project}"
  target_key_id = aws_kms_key.main.key_id
}

# ---------- S3: Terraform state + audit ----------
resource "aws_s3_bucket" "state" { bucket = "${var.project}-tfstate-${local.acct}" }
resource "aws_s3_bucket" "audit" { bucket = "${var.project}-audit-${local.acct}" }

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_versioning" "audit" {
  bucket = aws_s3_bucket.audit.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
  }
}
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_public_access_block" "audit" {
  bucket                  = aws_s3_bucket.audit.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------- ECR ----------
resource "aws_ecr_repository" "repo" {
  for_each             = toset(["api", "frontend"])
  name                 = "${var.project}-${each.key}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.main.arn
  }
}

# ---------- GitHub OIDC + CI role ----------
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repo}:ref:refs/heads/main",
        "repo:${var.github_repo}:ref:refs/heads/vuln-demo",
      ]
    }
  }
}

resource "aws_iam_role" "ci" {
  name               = "${var.project}-ci-deploy"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

data "aws_iam_policy_document" "ci" {
  # Registry: push/pull only our two repos
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload",
      "ecr:PutImage", "ecr:DescribeImages",
    ]
    resources = [for r in aws_ecr_repository.repo : r.arn]
  }
  # State + audit buckets only
  statement {
    actions = ["s3:ListBucket", "s3:GetBucketVersioning"]
    resources = [aws_s3_bucket.state.arn, aws_s3_bucket.audit.arn]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/*"]
  }
  statement {
    actions   = ["s3:PutObject"] # write-only to audit: CI cannot read or delete records
    resources = ["${aws_s3_bucket.audit.arn}/*"]
  }
  statement {
    actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = [aws_kms_key.main.arn]
  }
  # Terraform apply for the app stack. Scoped by SERVICE (not per-resource) because Terraform
  # must create new resources. See README "Known trade-offs" and add a permissions boundary for production.
  statement {
    actions = [
      "ec2:*", "ecs:*", "elasticloadbalancing:*", "rds:*", "wafv2:*", "logs:*",
      "cloudtrail:*", "secretsmanager:*", "s3:*", "application-autoscaling:*",
    ]
    resources = ["*"]
  }
  # IAM only for roles/policies named securedeploy-*
  statement {
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:PassRole", "iam:TagRole",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy",
      "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole", "iam:CreateServiceLinkedRole",
    ]
    resources = ["arn:aws:iam::${local.acct}:role/${var.project}-*", "arn:aws:iam::${local.acct}:role/aws-service-role/*"]
  }
}

resource "aws_iam_role_policy" "ci" {
  name   = "ci-deploy"
  role   = aws_iam_role.ci.id
  policy = data.aws_iam_policy_document.ci.json
}

output "state_bucket" { value = aws_s3_bucket.state.bucket }
output "audit_bucket" { value = aws_s3_bucket.audit.bucket }
output "ecr_api" { value = aws_ecr_repository.repo["api"].repository_url }
output "ecr_frontend" { value = aws_ecr_repository.repo["frontend"].repository_url }
output "ci_role_arn" { value = aws_iam_role.ci.arn }
output "region" { value = var.region }
