terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.80" }
  }
  # Bucket/region passed at init time: terraform init -backend-config=...
  # use_lockfile = native S3 state locking (Terraform 1.10+)
  backend "s3" {
    key          = "securedeploy/main.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region
  default_tags { tags = { Project = "securedeploy" } }
}

data "aws_caller_identity" "me" {}
data "aws_availability_zones" "az" { state = "available" }
