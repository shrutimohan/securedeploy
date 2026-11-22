output "app_url" { value = "http://${aws_lb.main.dns_name}" }
output "waf_log_group" { value = aws_cloudwatch_log_group.waf.name }
output "api_log_group" { value = aws_cloudwatch_log_group.api.name }
output "cloudtrail_log_group" { value = aws_cloudwatch_log_group.trail.name }
