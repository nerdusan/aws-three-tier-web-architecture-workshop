# DB Subnet Group
resource "aws_db_subnet_group" "db" {
  name       = "aurora-db-subnet-group"
  subnet_ids = [aws_subnet.db_1.id, aws_subnet.db_2.id]
  tags       = { Name = "aurora-subnets" }
}

# Aurora Multi-AZ Cluster
resource "aws_rds_cluster" "aurora" {
  cluster_identifier      = "aurora-mysql-cluster"
  engine                  = "aurora-mysql"
  engine_version          = "8.0.mysql_aurora.3.04.0"
  database_name           = "appdb"
  master_username         = "admin"
  master_password         = "SuperSecretPassword123!" 
  backup_retention_period = 7
  preferred_backup_window = "02:00-03:00"
  db_subnet_group_name    = aws_db_subnet_group.db.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  skip_final_snapshot     = true
}

# Multi-AZ Instances
resource "aws_rds_cluster_instance" "aurora_instances" {
  count              = 2
  identifier         = "aurora-instance-${count.index}"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = "db.r6g.large"
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version
  publicly_accessible = false
}
