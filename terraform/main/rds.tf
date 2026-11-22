resource "aws_db_subnet_group" "db" {
  name       = "${var.project}-db"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_db_instance" "db" {
  identifier     = "${var.project}-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_encrypted = true # encryption at rest

  db_name  = "appdb"
  username = "appuser"
  # RDS creates + rotates the password in Secrets Manager. It never appears in code or Terraform state.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  iam_database_authentication_enabled = true
  enabled_cloudwatch_logs_exports     = ["postgresql"]
  backup_retention_period             = 1
  auto_minor_version_upgrade          = true
  copy_tags_to_snapshot               = true

  # Lab settings so `terraform destroy` works. Turn both around for real systems.
  skip_final_snapshot = true
  deletion_protection = false
}
