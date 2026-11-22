# Attack-Tracing Report

Target: `http://<alb-dns>`   Attacker: Kali VM, IP `<ip>`   Window: `<start>` to `<end>` UTC

For each scenario: **Raw log -> Filtered finding -> Conclusion**.

## 1. SQL injection (sqlmap / manual) on /api/search
- **Raw log** (paste one WAF log JSON line):
  ```
  { "action": "BLOCK", "terminatingRuleId": "aws-sqli", "httpRequest": { ... } }
  ```
- **Filtered finding** (query used + count): `...`  -> N blocked, M allowed
- **Did any reach the app?** (API log check): yes/no
- **Conclusion:** e.g. "SQLi blocked by AWSManagedRulesSQLiRuleSet; 0 payloads reached the API."

## 2. XSS payloads
- Raw log / Query / Conclusion

## 3. Brute force on /api/login (hydra)
- **Raw WAF log:** action ALLOW (WAF has no signature for a bad password)
- **Raw API log:** `LOGIN_FAIL bad_password user=admin ip=...` x N, then `LOGIN_OK`
- **Conclusion:** "WAF does not stop credential guessing. The weak login is only visible in app logs. Fix: lockout, MFA, rate rule scoped to /api/login."

## 4. Rate-limit burst
- Raw log (`terminatingRuleId: rate-limit`), requests before block (~100), conclusion.

## 5. CloudTrail correlation
- Query used; events in the window; conclusion: "No IAM/API activity from attacker IP. Only ECS execution-role GetSecretValue at task start."

## Gaps found / recommended fixes
| Gap | Evidence | Fix |
|---|---|---|

## Timeline
| Time (UTC) | Source | Event |
|---|---|---|
