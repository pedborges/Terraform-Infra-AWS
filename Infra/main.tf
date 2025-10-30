provider "aws" {
  region = "sa-east-1"
}

resource "aws_ecr_repository" "webapi" {
  name = "demo_project_repository"
}

# this define that any App Runner service can assume this role
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["build.apprunner.amazonaws.com"] #if you are an app runner service you can use this service principal
    }

    actions = ["sts:AssumeRole"]
  }
}
# Create the IAM role and the assume_role_policy defines which kind of service can assume this role
#this is like a costume that App Runner will wear to be able to access ECR
resource "aws_iam_role" "apprunner_ecr_role" {
  name               = "AppRunnerECRAccess"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json

  tags = {
    Name       = "AppRunnerECRAccess"
    ManagedBy  = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.apprunner_ecr_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_apprunner_service" "myDemoProject_AppRunnerService" {
  service_name = var.app_runner_service_name

  source_configuration {
    image_repository {
      image_configuration {
        port = "8000"
      }
      image_identifier      = "795772440200.dkr.ecr.sa-east-1.amazonaws.com/demo_project_repository:latest"
      image_repository_type = "ECR_Private"
    }
    auto_deployments_enabled = true
      authentication_configuration {
    access_role_arn = aws_iam_role.apprunner_ecr_role.arn
  }
  }

  tags = {
        ManagedBy  = "Terraform"
        Environment = "dev"
  }
}