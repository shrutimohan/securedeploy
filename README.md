# SecureDeploy: DevSecOps pipeline for a 3-tier app on AWS

Intentionally vulnerable app (`/api/login`, `/api/search`) + secured AWS landing zone + 3-stage security pipeline.
**Never expose this app unprotected. Attack only your own deployment.**

## Layout
```
app/                 frontend (nginx), api (Flask), db init, docker-compose
terraform/bootstrap  state bucket, audit bucket, ECR, KMS, GitHub OIDC + CI role (run once, locally)
terraform/main       VPC, SGs, RDS, ECS Fargate, ALB, WAF, CloudTrail, logging (run by the pipeline)
.github/workflows    pr-checks.yml (stage 1), build.yml (stage 2), deploy.yml (stage 3)
attacks/             run_attacks.sh, Logs Insights queries, report template
scripts/             demo-unsigned.sh (proves unsigned images are rejected)
evidence/            before/after checklist
```

## Quick start

### 1. Run locally
```bash
cd app && docker compose up --build      # http://localhost:8080
```
Test: login `admin/admin123`; search `' OR '1'='1` returns every product (SQLi works).

### 2. Push to GitHub
Create repo `securedeploy`, push this folder to `main`. Create a `vuln-demo` branch too.

### 3. Bootstrap AWS (once, your admin credentials)
```bash
cd terraform/bootstrap
terraform init
terraform apply -var github_repo=YOUR_USER/securedeploy -var region=ap-south-1
```
If your account already has a GitHub OIDC provider, import it:
`terraform import aws_iam_openid_connect_provider.github arn:aws:iam::ACCOUNT:oidc-provider/token.actions.githubusercontent.com`

### 4. GitHub settings (Settings -> Secrets and variables -> Actions -> Variables)
| Variable | Value (from bootstrap outputs) |
|---|---|
| AWS_REGION | ap-south-1 |
| AWS_ROLE_ARN | `ci_role_arn` |
| STATE_BUCKET | `state_bucket` |
| AUDIT_BUCKET | `audit_bucket` |
| ALLOWED_CIDRS | `["YOUR.PUBLIC.IP/32"]` (JSON list) |
| ENFORCE_GATES | `false` for the "before" run, `true` for "after" |

Also: Settings -> Branches -> protect `main`, require status checks `semgrep`, `secrets`, `iac`, require PRs.
Enable Code scanning (Security tab) for SARIF annotations.

### 5. Deploy ("before": vulnerable build passes)
Set `ENFORCE_GATES=false`, push to `vuln-demo` (or `main`). `build` -> `deploy` run automatically.
Get the URL: terraform output `app_url` (or the EC2 console -> Load balancers).

### 6. Attack (from Kali)
```bash
CONFIRM_OWN_TARGET=yes ./attacks/run_attacks.sh http://<alb-dns>
```
Then run the queries in `attacks/logs_insights_queries.md` and fill `attacks/REPORT_TEMPLATE.md`.

### 7. "After": pipeline blocks it
Set `ENFORCE_GATES=true`. Open a PR containing the vulnerable code: Semgrep (SQLi) and Checkov fail, merge is blocked.
Show Trivy failing by temporarily changing the API base image to an old one (e.g. `python:3.8`).
Run `./scripts/demo-unsigned.sh REGION ACCOUNT_ID`, then run the `deploy` workflow manually with that digest: it fails at Cosign verify.

### 8. Clean up (important, costs money while running)
Run `terraform destroy` in `terraform/main` (with the same -var values and backend config), then in `terraform/bootstrap`
(empty the S3 buckets first because they are versioned).

## Cost warning
ALB, RDS, 4 interface VPC endpoints (~$0.01/h each per AZ), Fargate, WAF all bill hourly. Roughly $3-5/day. Destroy when done.

## Known trade-offs (document these in your report)
- **HTTP only**: no domain, so no ACM cert. Use HTTPS in real systems.
- **CI role is service-scoped, not resource-scoped** for Terraform-managed services, because Terraform must create new resources. Mitigate with a permissions boundary and by scoping IAM to `securedeploy-*` (already done). ECR, S3, KMS are tightly scoped; audit bucket is write-only for CI.
- **Checkov may flag things** (e.g. ALB access logs, ECR/KMS details). Fix them or add documented `#checkov:skip=ID:reason` comments. Do not use blanket ignores.
- **Semgrep will flag the intentional SQLi** (that is the point). The documented exception is that enforcement is toggled with `ENFORCE_GATES`, not by silencing rules.
- **Action versions are pinned to tags**; for stronger supply-chain security pin to commit SHAs.
- Validate Terraform before applying: `terraform fmt && terraform validate` (not run in the authoring environment).

## Secrets handling
RDS `manage_master_user_password=true` stores the DB password in Secrets Manager. It never appears in code or Terraform state; ECS injects it at start via `secrets/valueFrom`. The only hard-coded password is `localdevonly` in docker-compose (laptop only), which gitleaks/Trivy may flag.
