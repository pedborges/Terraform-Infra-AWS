provider "aws" {
  region = "us-east-1"
}
data "aws_iam_role" "apprunner_ecr_role" {
  name = "AppRunnerECRAccess"
}
resource "aws_ecr_repository" "webapi" {
  name = "demo_project_repository"
}
resource "aws_apprunner_service" "my_demo_project_service" {
  service_name = var.app_runner_service_name

  source_configuration {
    authentication_configuration {
      access_role_arn = data.aws_iam_role.apprunner_ecr_role.arn
    }

    image_repository {
      image_identifier      = "795772440200.dkr.ecr.us-east-1.amazonaws.com/demo_project_repository:latest"
      image_repository_type = "ECR"
      image_configuration {
        port = "80"
      }
    }
 
    auto_deployments_enabled = true
  }
  health_check_configuration {
      protocol             = "HTTP"
      path                 = "/health"
      healthy_threshold    = 1
      unhealthy_threshold  = 5
      interval             = 10
      timeout              = 5
    }


  instance_configuration {
    cpu    = "1024" # 1 vCPU
    memory = "2048" # 2 GB
  }

  tags = {
    ManagedBy = "Terraform"
  }
}
# this define that any App Runner service can assume this role
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["build.apprunner.amazonaws.com"] #if you are an app runner service you can use this service principal.
    }

    actions = ["sts:AssumeRole"]
  }
}
# Create the IAM role and the assume_role_policy defines which kind of service can assume this role
#this is like a costume that App Runner will wear to be able to access ECR
# resource "aws_iam_role" "apprunner_ecr_role" {
#  name               = "AppRunnerECRAccess"
#  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json

#   tags = {
#      Name       = "AppRunnerECRAccess"
#      ManagedBy  = "Terraform"
#     }
#}

# resource "aws_iam_role_policy_attachment" "ecr_access" {
#  role       = aws_iam_role.apprunner_ecr_role.name
#  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
#}

