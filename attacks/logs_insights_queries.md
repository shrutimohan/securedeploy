# CloudWatch Logs Insights queries

Set the time range to cover your attack window (use the timestamps in your attack log).

## WAF log group: `aws-waf-logs-securedeploy`

**All blocked requests, grouped by rule**
```
filter action = "BLOCK"
| stats count(*) as hits by terminatingRuleId
| sort hits desc
```

**Raw blocked SQLi requests**
```
fields @timestamp, action, terminatingRuleId, httpRequest.clientIp, httpRequest.uri, httpRequest.args, httpRequest.headers.0.value
| filter action = "BLOCK" and terminatingRuleId like /sqli/i
| sort @timestamp desc
| limit 50
```

**XSS blocks (Common rule set)**
```
fields @timestamp, terminatingRuleId, nonTerminatingMatchingRules, httpRequest.uri, httpRequest.args
| filter action = "BLOCK" and terminatingRuleId = "aws-common"
| limit 50
```

**Rate limit blocks**
```
fields @timestamp, httpRequest.clientIp, httpRequest.uri
| filter terminatingRuleId = "rate-limit"
| stats count(*) as blocked by bin(1m)
```

**Requests that were ALLOWED but looked like attacks (WAF gaps)**
```
fields @timestamp, action, httpRequest.clientIp, httpRequest.uri, httpRequest.args
| filter action = "ALLOW" and httpRequest.uri = "/api/login"
| stats count(*) as attempts by httpRequest.clientIp
```

## API log group: `/securedeploy/api`

**Failed logins (what hydra left behind: visible only here)**
```
fields @timestamp, @message
| filter @message like /LOGIN_FAIL/
| stats count(*) as fails by bin(1m)
```

**Successful login after many failures (brute-force success)**
```
fields @timestamp, @message
| filter @message like /LOGIN_OK/ or @message like /LOGIN_FAIL/
| sort @timestamp asc
```

**Search payloads that reached the app (SQLi that got through, if any)**
```
fields @timestamp, @message
| filter @message like /SEARCH q=/ and @message like /(UNION|OR '1'|--)/
```

## CloudTrail log group: `/securedeploy/cloudtrail`

**Role and secret activity during the attack window**
```
fields @timestamp, eventName, userIdentity.arn, sourceIPAddress, requestParameters.secretId
| filter eventName in ["AssumeRole","GetSecretValue","UpdateService","RegisterTaskDefinition"]
| sort @timestamp desc
| limit 50
```

**Anything denied**
```
fields @timestamp, eventName, errorCode, userIdentity.arn
| filter ispresent(errorCode)
```
Expected: `GetSecretValue` by the ECS execution role at task start (not by the app during attacks).
If you see API calls from your Kali IP, investigate: attacks against the web app should NOT create IAM/API events.
