variable "region" { default = "ap-south-1" }
variable "project" { default = "securedeploy" }

variable "allowed_cidrs" {
  description = "Who may reach the ALB. Set to YOUR_IP/32 while testing. Never leave 0.0.0.0/0 with the vulnerable app."
  type        = list(string)
}

variable "api_image" {
  description = "Full image reference BY DIGEST, e.g. 123.dkr.ecr.../securedeploy-api@sha256:..."
  type        = string
}
variable "frontend_image" {
  type = string
}
