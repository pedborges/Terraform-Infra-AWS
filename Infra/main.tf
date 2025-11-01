provider "aws" {
  region = "us-east-2"
}

resource "aws_ecr_repository" "webapi" {
  name = "demo_project_repository"
}



# Create the IAM role and the assume_role_policy defines which kind of service can assume this role
#this is like a costume that App Runner will wear to be able to access ECR
# resource "aws_iam_role" "apprunner_ecr_role" {
#  name               = "AppRunnerECRAccess"
#  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json.

#   tags = {
#      Name       = "AppRunnerECRAccess"
#      ManagedBy  = "Terraform"
#     }
#}

# resource "aws_iam_role_policy_attachment" "ecr_access" {
#  role       = aws_iam_role.apprunner_ecr_role.name
#  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
#}

#resource "aws_apprunner_service" "my_demo_project_service" {
  #service_name = var.app_runner_service_name

  #source_configuration {
  #  authentication_configuration {
 #      access_role_arn = data.aws_iam_role.apprunner_ecr_role.arn
 #   }

 #   image_repository {
 #     image_identifier      = "795772440200.dkr.ecr.us-east-1.amazonaws.com/demo_project_repository:latest"
 #     image_repository_type = "ECR"
 #     image_configuration {
 #       port = "8080"
 #       runtime_environment_variables = {
 #            "Jwt__Key"      = "your_super_secret_jwt_key_change_me"
 #            "Jwt__Issuer"   = "MYDemoProjectURL"
 #            "Jwt__Audience" = "your-audience"
 #            "ASPNETCORE_ENVIRONMENT" = "Production"
 #            "ASPNETCORE_HTTP_PORTS" = "8080"
 #            "TokenData__SecretAPIKey"= "default_secret_key_please_change_it"
 #            "ConnectionStrings__DefaultConnection" = "Server=YOUR_SERVER_NAME;Database=YourDatabaseName;User Id=YOUR_USER;Password=YOUR_PASSWORD;TrustServerCertificate=True;"
 #       }
 #     }
 #   }
 
#    auto_deployments_enabled = true
#  }
#  health_check_configuration {
#      protocol             = "HTTP"
#      path                 = "/health"
#      healthy_threshold    = 1
#      unhealthy_threshold  = 5
#      interval             = 10
#      timeout              = 5
#    }


#  instance_configuration {
#    cpu    = "1024" # 1 vCPU.
#    memory = "2048" # 2 GB
#  }

#  tags = {
#    ManagedBy = "Terraform"
#  }
#}
