# =============================
# ======= Relational DB =======
# =============================
resource "aws_db_parameter_group" "example" {
  name   = "example"
  family = "mysql5.7"

  parameter {
    name  = "character_set_database"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  tags = {
    Name = "example_db_param_grp"
  }
}

resource "aws_db_option_group" "example" {
  name                 = "example"
  engine_name          = "mysql"
  major_engine_version = "5.7"

  option {
    option_name = "MARIADB_AUDIT_PLUGIN"
  }

  tags = {
    Name = "example_db_option_grp"
  }
}

resource "aws_db_subnet_group" "example" {
  name       = "example"
  subnet_ids = [aws_subnet.private_0.id, aws_subnet.private_1.id]

  tags = {
    Name = "example_db_subnet_grp"
  }
}

resource "aws_db_instance" "example" {
  identifier                 = "example"
  engine                     = "mysql"
  engine_version             = "5.7.41" #2023/03/19現在、5.7.25が使用不可であっため、「5.7.41」(同マイナーバージョン内の最新パッチバージョンを選択)に変更とした
  instance_class             = "db.t3.small"
  allocated_storage          = 20
  max_allocated_storage      = 100
  storage_type               = "gp2" #汎用SSD
  storage_encrypted          = true
  kms_key_id                 = aws_kms_key.example.arn #Terraformにて作成した、本ハンズオン用のExample Customer Master Keyを指定
  username                   = "admin"
  password                   = "VeryStrongPassword!" #仮設定. 後ほど変更
  multi_az                   = true                  #マルチAZ対応
  publicly_accessible        = false                 #VPC外からのアクセスを禁止
  backup_window              = "09:10-09:40"
  backup_retention_period    = 30
  maintenance_window         = "mon:10:10-mon:10:40"
  auto_minor_version_upgrade = false #OSやデータベースエンジンのAWS管理による自動マイナーバージョンアップを無効化
  deletion_protection        = false #削除保護は、terraformでの一括destroyにて削除できるように「無効」とする
  skip_final_snapshot        = true  #terraformでの一括destroyにて削除できるように「有効」とし、スナップショットの作成をスキップする
  port                       = 3306  #MySQLのデフォルトポート番号を指定
  apply_immediately          = false #予期せぬダウンタイム回避のために、変更即時反映を無効化
  vpc_security_group_ids     = [module.mysql_sg.security_group_id]
  parameter_group_name       = aws_db_parameter_group.example.name
  option_group_name          = aws_db_option_group.example.name
  db_subnet_group_name       = aws_db_subnet_group.example.name

  lifecycle {
    ignore_changes = [password]
  }

  tags = {
    Name = "example_db"
  }
}

module "mysql_sg" {
  source      = "./security_group"
  name        = "mysql-sg"
  vpc_id      = aws_vpc.example.id
  port        = 3306
  cidr_blocks = [aws_vpc.example.cidr_block]
}

# ===============================
# ======= In-Memory-Store =======
# ===============================
resource "aws_elasticache_parameter_group" "example" {
  name   = "example"
  family = "redis5.0"

  parameter {
    name  = "cluster-enabled"
    value = "no"
  }

  tags = {
    Name = "example_elasticache_param_grp"
  }
}

resource "aws_elasticache_subnet_group" "example" {
  name       = "example"
  subnet_ids = [aws_subnet.private_0.id, aws_subnet.private_1.id] #マルチAZ対応のために、ap-northeast-1aと1cの2つのサブネットを指定

  tags = {
    Name = "example_elasticache_subnet_grp"
  }
}

resource "aws_elasticache_replication_group" "example" {
  replication_group_id       = "example"
  description                = "Cluster Disabled"
  engine                     = "redis"
  engine_version             = "5.0.6" #2023/03/19現在、5.0.4が使用不可であっため、「5.0.6」(同マイナーバージョン内の最新パッチバージョンを選択)に変更とした
  num_cache_clusters         = 3
  node_type                  = "cache.m6g.large" #2023/03/19現在、cache.m3.mediumが使用不可であっため、「cache.m6g.large」(汎用ファミリー(m)の最新世代(6)の最小サイズ)に変更とした
  snapshot_window            = "09:10-10:10"
  snapshot_retention_limit   = 7
  maintenance_window         = "mon:10:40-mon:11:40"
  automatic_failover_enabled = true  #マルチAZが前提の自動フェイルオーバを有効可
  port                       = 6379  #Redisのデフォルトポート番号を指定
  apply_immediately          = false #予期せぬダウンタイム回避のために、変更即時反映を無効化
  security_group_ids         = [module.redis_sg.security_group_id]
  parameter_group_name       = aws_elasticache_parameter_group.example.name
  subnet_group_name          = aws_elasticache_subnet_group.example.name

  tags = {
    Name = "example_elasticache_replica_grp"
  }
}

module "redis_sg" {
  source      = "./security_group"
  name        = "redis-sg"
  vpc_id      = aws_vpc.example.id
  port        = 6379
  cidr_blocks = [aws_vpc.example.cidr_block]
}
