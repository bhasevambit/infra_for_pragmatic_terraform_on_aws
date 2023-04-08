terraform {
  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.59.0"
    }
  }

  backend "s3" {
    bucket  = "terraform-backend-353981446712" #手動で作成したterraform バックエンド用のS3バケット名
    region  = "ap-northeast-1"
    key     = "Pragmatic_Terraform_on_AWS_Book_MyCodes_tfstateFile/terraform.tfstate"
    encrypt = true
  }
}

provider "aws" {
  region = "ap-northeast-1"

  default_tags {
    tags = {
      Managed   = "terraform"
      Reference = "pragmatic_terraform_on_aws"
    }
  }
}
