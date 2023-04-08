data "aws_caller_identity" "current" {}
# data.aws_caller_identity.current.account_id
# でアカウントIDを取得できる

resource "aws_s3_bucket" "private" {
  bucket        = "private-pragmatic-terraform-${data.aws_caller_identity.current.account_id}"
  force_destroy = true #S3バケット内にデータが残っている場合における強制的なバケット削除の有効化
  tags = {
    Name = "example_s3_private"
  }
}

resource "aws_s3_bucket_versioning" "private" {
  bucket = aws_s3_bucket.private.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "private" {
  bucket = aws_s3_bucket.private.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "private" {
  bucket                  = aws_s3_bucket.private.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "public" {
  bucket        = "public-pragmatic-terraform-${data.aws_caller_identity.current.account_id}"
  force_destroy = true #S3バケット内にデータが残っている場合における強制的なバケット削除の有効化
  tags = {
    Name = "example_s3_public"
  }
}

resource "aws_s3_bucket_cors_configuration" "public" {
  bucket = aws_s3_bucket.public.id

  cors_rule {
    allowed_origins = ["https://example.com"]
    allowed_methods = ["GET"]
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_acl" "public" {
  bucket = aws_s3_bucket.public.id
  acl    = "public-read"
}

resource "aws_s3_bucket" "alb_log" {
  bucket        = "alb-log-pragmatic-terraform-${data.aws_caller_identity.current.account_id}"
  force_destroy = true #S3バケット内にデータが残っている場合における強制的なバケット削除の有効化
  tags = {
    Name = "example_s3_alb_log"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_log" {
  bucket = aws_s3_bucket.alb_log.id

  rule {
    id     = "rule-1"
    status = "Enabled"

    expiration {
      days = "180"
    }
  }
}


resource "aws_s3_bucket_policy" "alb_log" {
  bucket = aws_s3_bucket.alb_log.id
  policy = data.aws_iam_policy_document.alb_log.json
}

data "aws_iam_policy_document" "alb_log" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.alb_log.id}/*"]

    principals {
      type        = "AWS"
      identifiers = ["582318560864"] #東京リージョン(ap-northeast-1)の「AWSがELBの管理を行っているAWSアカウントID」を指定 (ALBログのS3書き込み向け情報)
    }
  }
}
