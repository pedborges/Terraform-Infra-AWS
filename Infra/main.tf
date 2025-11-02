terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.24.0"
    }
  }

  required_version = ">= 1.5.0"
}
provider "aws" {
  region = "us-east-1"
}


resource "aws_ecr_repository" "webapi" {
  name = "demo_project_repository"
}

resource "aws_apprunner_service" "this" {
  service_name = var.service_name

  source_configuration {
    image_repository {
      image_identifier      = "${aws_ecr_repository.webapi.repository_url}:${var.image_tag}"
      image_repository_type = "ECR"

      image_configuration {
        port = "8080"
        runtime_environment_variables = {
          ASPNETCORE_ENVIRONMENT = "Production"
        }
      }
    }

    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner_ecr_role.arn
    }
  }

  network_configuration {
    egress_configuration {
      egress_type = "DEFAULT"
    }

    ingress_configuration {
      is_publicly_accessible = true
    }
  }

  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration.this.arn
  tags = {
  Project = "MyDemoProject"
  Environment = "Production"
 } 
}

resource "aws_iam_role" "apprunner_ecr_role" {
  name = "AppRunnerECRAccess"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = [
           "build.apprunner.amazonaws.com",
           "tasks.apprunner.amazonaws.com"
          ]
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = {
  Project = "MyDemoProject"
  Environment = "Production"
}
}

resource "aws_iam_role_policy" "apprunner_ecr_policy" {
  name = "AppRunnerECRPolicy"
  role = aws_iam_role.apprunner_ecr_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ],
        Resource = "*"
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# AUTO SCALING CONFIGURATION
# ------------------------------------------------------------------------------
resource "aws_apprunner_auto_scaling_configuration" "this" {
  auto_scaling_configuration_name = "${var.service_name}-scaling"
  max_concurrency                 = 50
  max_size                        = 1
  min_size                        = 1
}

# ------------------------------------------------------------------------------
# CUSTOM DOMAIN WITH ACM CERTIFICATE
# ------------------------------------------------------------------------------
resource "aws_apprunner_custom_domain_association" "this" {
  service_arn = aws_apprunner_service.this.arn
  domain_name = "api.dinherama.com"
  depends_on = [aws_apprunner_service.this]
}

# ------------------------------------------------------------------------------
# OUTPUTS
# ------------------------------------------------------------------------------
output "apprunner_service_url" {
  value = aws_apprunner_service.this.service_url
}
