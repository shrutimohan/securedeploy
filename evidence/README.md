# Evidence checklist (before / after)

## BEFORE: vulnerable build passes nothing (branch `vuln-demo`, ENFORCE_GATES=false)
- [ ] Screenshot: PR checks show findings but are not blocking (green merge button)
- [ ] Screenshot: Security tab -> Code scanning alerts (Semgrep SQLi, Checkov, Trivy)
- [ ] Screenshot: build + deploy workflow succeeded
- [ ] Attack results from `attacks/run_attacks.sh`

## AFTER: pipeline blocks it (branch `main`, ENFORCE_GATES=true)
- [ ] Screenshot: PR with the vulnerable code, red X on semgrep / checkov / trivy
- [ ] Screenshot: merge button blocked by branch protection
- [ ] Screenshot: Trivy CRITICAL failure in build log (use an old base image, e.g. python:3.8)
- [ ] Screenshot: `deploy` workflow failing at "Cosign verify" with the unsigned image
- [ ] Screenshot: `audit-record.json` in the S3 audit bucket (versioned)
