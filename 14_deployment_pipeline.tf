resource "aws_ecr_repository" "example" {
  name         = "example"
  force_delete = true
}

resource "aws_ecr_lifecycle_policy" "example" {
  repository = aws_ecr_repository.example.name

  policy = <<EOF
  {
    "rules": [
      {
        "rulePriority": 1,
        "description": "Keep last 30 release tagged images",
        "selection": {
          "tagStatus": "tagged",
          "tagPrefixList": ["release"],
          "countType": "imageCountMoreThan",
          "countNumber": 30
        },
        "action": {
          "type": "expire"
        }
      }
    ]
  }
EOF
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "codestar-connections:UseConnection"
    ]
  }
}

module "codebuild_role" {
  source     = "./iam_role"
  name       = "codebuild"
  identifier = "codebuild.amazonaws.com"
  policy     = data.aws_iam_policy_document.codebuild.json
}

resource "aws_codebuild_project" "example" {
  name         = "example"
  service_role = module.codebuild_role.iam_role_arn

  source {
    type = "CODEPIPELINE"
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    type            = "LINUX_CONTAINER"
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:2.0"
    privileged_mode = true
  }

  tags = {
    Name = "example_codebuild_prj"
  }
}

data "aws_iam_policy_document" "codepipeline" {
  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeTasks",
      "ecs:ListTasks",
      "ecs:RegisterTaskDefinition",
      "ecs:UpdateService",
      "iam:PassRole",
      "codestar-connections:UseConnection"
    ]
  }
}

module "codepipeline_role" {
  source     = "./iam_role"
  name       = "codepipeline"
  identifier = "codepipeline.amazonaws.com"
  policy     = data.aws_iam_policy_document.codepipeline.json
}

resource "aws_s3_bucket" "artifact" {
  bucket        = "artifact-pragmatic-terraform-${data.aws_caller_identity.current.account_id}"
  force_destroy = true #S3バケット内にデータが残っている場合における強制的なバケット削除の有効化
  tags = {
    Name = "example_s3_artifact"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifact" {
  bucket = aws_s3_bucket.artifact.id

  rule {
    id     = "rule-1"
    status = "Enabled"

    expiration {
      days = "180"
    }
  }
}

#variable "GITHUB_TOKEN" {}

resource "aws_codestarconnections_connection" "github" {
  name          = "example-connection"
  provider_type = "GitHub"

  tags = {
    Name = "example_codestarconnections_github"
  }
}

resource "aws_codepipeline" "example" {
  name     = "example"
  role_arn = module.codepipeline_role.iam_role_arn

  stage {
    name = "Source"

    // --- Source Actionについては、2023年3月時点で、推奨形式であるCodePipeline - GitHub連携version2(CodeStarConnection)を使う事とした  ---
    // see: https://qiita.com/KensukeTakahara/items/6ed83e83620b86b748b7
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = 1
      output_artifacts = ["Source"]

      configuration = {
        ConnectionArn        = aws_codestarconnections_connection.github.arn
        FullRepositoryId     = "bhasevambit/app_for_pragmatic_terraform_on_aws"
        BranchName           = "main"
        OutputArtifactFormat = "CODEBUILD_CLONE_REF"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = 1
      input_artifacts  = ["Source"]
      output_artifacts = ["Build"]

      configuration = {
        ProjectName = aws_codebuild_project.example.id
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = 1
      input_artifacts = ["Build"]

      configuration = {
        ClusterName = aws_ecs_cluster.example.name
        ServiceName = aws_ecs_service.example.name
        FileName    = "imagedefinitions.json"
      }
    }
  }

  artifact_store {
    location = aws_s3_bucket.artifact.id
    type     = "S3"
  }
}

// --- 2023年3月時点で、推奨形式であるCodePipeline - GitHub連携version2(CodeStarConnection)を使う事とした事から、webhookによる連携を無効化 ---
# resource "aws_codepipeline_webhook" "example" {
#   name            = "example"
#   target_pipeline = aws_codepipeline.example.name
#   target_action   = "Source"
#   authentication  = "GITHUB_HMAC"

#   authentication_configuration {
#     secret_token = ""
#   }

#   filter {
#     json_path    = "$.ref"
#     match_equals = "refs/heads/{Branch}"
#   }
# }

# provider "github" {
#   owner = "bhasevambit"
# }

# resource "github_repository_webhook" "example" {
#   repository = "pragmatic_terraform_test"

#   name = "web"

#   configuration {
#     url          = aws_codepipeline_webhook.example.url
#     secret       = ""
#     content_type = "json"
#     insecure_ssl = false
#   }

#   events = ["push"]
# }
