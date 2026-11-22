# Copy to terraform.tfvars (git-ignored). Use YOUR public IP: curl ifconfig.me
allowed_cidrs  = ["203.0.113.10/32"]
api_image      = "123456789012.dkr.ecr.ap-south-1.amazonaws.com/securedeploy-api@sha256:REPLACE"
frontend_image = "123456789012.dkr.ecr.ap-south-1.amazonaws.com/securedeploy-frontend@sha256:REPLACE"
