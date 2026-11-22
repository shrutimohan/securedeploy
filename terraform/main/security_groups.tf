# Chain: internet(allowed_cidrs) -> ALB:80 -> API:5000 / WEB:80 ; API -> RDS:5432. No CIDR rules between tiers.
resource "aws_security_group" "alb" {
  name        = "${var.project}-alb"
  description = "ALB"
  vpc_id      = aws_vpc.main.id
}
resource "aws_security_group" "web" {
  name        = "${var.project}-web"
  description = "Frontend tasks"
  vpc_id      = aws_vpc.main.id
}
resource "aws_security_group" "api" {
  name        = "${var.project}-api"
  description = "API tasks"
  vpc_id      = aws_vpc.main.id
}
resource "aws_security_group" "db" {
  name        = "${var.project}-db"
  description = "RDS"
  vpc_id      = aws_vpc.main.id
}
resource "aws_security_group" "vpce" {
  name        = "${var.project}-vpce"
  description = "VPC endpoints"
  vpc_id      = aws_vpc.main.id
}

# ALB
resource "aws_vpc_security_group_ingress_rule" "alb_in" {
  for_each          = toset(var.allowed_cidrs)
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP from allowed IPs"
}
resource "aws_vpc_security_group_egress_rule" "alb_to_api" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.api.id
  from_port                    = 5000
  to_port                      = 5000
  ip_protocol                  = "tcp"
  description                  = "ALB to API"
}
resource "aws_vpc_security_group_egress_rule" "alb_to_web" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.web.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "ALB to frontend"
}

# Frontend
resource "aws_vpc_security_group_ingress_rule" "web_in" {
  security_group_id            = aws_security_group.web.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "From ALB"
}
resource "aws_vpc_security_group_egress_rule" "web_vpce" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = aws_vpc.main.cidr_block
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "VPC endpoints (ECR, logs)"
}
resource "aws_vpc_security_group_egress_rule" "web_s3" {
  security_group_id = aws_security_group.web.id
  prefix_list_id    = aws_vpc_endpoint.s3.prefix_list_id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "S3 gateway (image layers)"
}

# API
resource "aws_vpc_security_group_ingress_rule" "api_in" {
  security_group_id            = aws_security_group.api.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 5000
  to_port                      = 5000
  ip_protocol                  = "tcp"
  description                  = "From ALB"
}
resource "aws_vpc_security_group_egress_rule" "api_db" {
  security_group_id            = aws_security_group.api.id
  referenced_security_group_id = aws_security_group.db.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "API to Postgres"
}
resource "aws_vpc_security_group_egress_rule" "api_vpce" {
  security_group_id = aws_security_group.api.id
  cidr_ipv4         = aws_vpc.main.cidr_block
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "VPC endpoints (ECR, logs, Secrets Manager)"
}
resource "aws_vpc_security_group_egress_rule" "api_s3" {
  security_group_id = aws_security_group.api.id
  prefix_list_id    = aws_vpc_endpoint.s3.prefix_list_id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "S3 gateway (image layers)"
}

# DB
resource "aws_vpc_security_group_ingress_rule" "db_in" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.api.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "Postgres from API only"
}

# VPC endpoints
resource "aws_vpc_security_group_ingress_rule" "vpce_in" {
  security_group_id = aws_security_group.vpce.id
  cidr_ipv4         = aws_vpc.main.cidr_block
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS from VPC"
}
