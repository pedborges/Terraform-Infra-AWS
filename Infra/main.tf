provider "aws" {
  region = "us-east-2"
}

resource "aws_ecr_repository" "webapi" {
  name = "demo_project_repository"
}
# --- Networking --------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

# --- ECS Cluster -------------------------------------------------
resource "aws_ecs_cluster" "api_cluster" {
  name = "myapi-cluster"
}

# --- IAM Role for Task Execution (to pull from ECR) --------------
resource "aws_iam_role" "ecs_task_exec_role" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_exec_attach" {
  role       = aws_iam_role.ecs_task_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- Security Group ---------------------------------------------
resource "aws_security_group" "ecs_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Task Definition --------------------------------------------
resource "aws_ecs_task_definition" "myapi_task" {
  family                   = "myapi-task"
  requires_compatibilities  = ["FARGATE"]
  network_mode              = "awsvpc"
  cpu                       = "256"   # 0.25 vCPU
  memory                    = "512"   # 0.5 GB
  execution_role_arn        = aws_iam_role.ecs_task_exec_role.arn
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "myapi",
      image     = "795772440200.dkr.ecr.us-east-1.amazonaws.com/demo_project_repository:latest",
      essential = true,
      portMappings = [{ containerPort = 8080, protocol = "tcp" }],
      environment = [
        { name = "ASPNETCORE_ENVIRONMENT", value = "Production" }
      ]
    }
  ])
}

# --- ECS Service -------------------------------------------------
resource "aws_ecs_service" "myapi_service" {
  name            = "myapi-service"
  cluster         = aws_ecs_cluster.api_cluster.id
  task_definition = aws_ecs_task_definition.myapi_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.public_a.id]
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  depends_on = [aws_iam_role_policy_attachment.ecs_task_exec_attach]
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
