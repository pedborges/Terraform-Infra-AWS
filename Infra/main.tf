#1️⃣ Client sends request: 
 #   https://myapi-alb-123.elb.amazonaws.com/health 

#2️⃣ ALB receives it on port 443. 
#   ↓ 
#  (Handled by HTTPS listener) 

#3️⃣ Listener says: 
#    “Forward this request to target group api_tg” 
#   ↓ 
#4️⃣ Target group has: 
#   IPs of your ECS tasks (e.g. 10.0.1.45:8080, 10.0.1.46:8080) 
#   ↓ 
#5️⃣ ALB picks a healthy task and forwards the request.

provider "aws" {
  region = "us-east-2"
}

resource "aws_ecr_repository" "webapi" {
  name = "demo_project_repository"
}
# --- Networking --------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16" //network range 10.0.0.0 – 10.0.255.255
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id //connect subnet to VPC
  cidr_block              = "10.0.1.0/24" //defines range of IPs in subnet (256 IPs)
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id //internet provider (ex: home router to access internet)
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id //belongs to the same VPC

  route {
    cidr_block = "0.0.0.0/0" //route to all IPs on the internet
    gateway_id = aws_internet_gateway.gw.id //through the internet gateway
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_a.id //binding the subnet that i defined above with the route table the i defined above
  route_table_id = aws_route_table.public.id //binding the subnet that i defined above with the route table the i defined above
}
# --- Load Balancer -----------------------------------
resource "aws_lb" "api-application-load-balancer" {
  name               = "api-application-load-balancer"
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_a.id]
  security_groups    = [aws_security_group.alb_sg.id]
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.api-application-load-balancer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect" #redirect HTTP to HTTPS
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.api-application-load-balancer.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:us-east-2:720283940682:certificate/fd7a3fa6-f202-41f6-8fb6-7e9399776280"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api-group-MyDemoProject.arn
  }
}
resource "aws_lb_target_group" "api-group-MyDemoProject" {
  name        = "api-group-MyDemoProject"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health" 
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}
# --- ECS Cluster -------------------------------------------------
resource "aws_ecs_cluster" "api_cluster" {
  name = "myapi-cluster" //a group of ECS services and tasks
}

# --- IAM Role for Task Execution (to pull from ECR) --------------
resource "aws_iam_role" "ecs_task_exec_role" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({ //defining who can assume this role
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_exec_attach" {
  role       = aws_iam_role.ecs_task_exec_role.name //binding the role defined above with the policy defined below
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_security_group" "alb_sg" {
  name   = "alb-sg"
  vpc_id = aws_vpc.main.id

  # Allow inbound HTTPS and HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443 //adding ssl port
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# --- Security Group ---------------------------------------------
#Without load balancer.
#resource "aws_security_group" "ecs_sg" {
#  vpc_id = aws_vpc.main.id  //VERY IMPORTANT: Define the firewall to allow traffic in and out of the container
#  ingress {
#    from_port   = 8080
#    to_port     = 8080
#    protocol    = "tcp"
#    cidr_blocks = ["0.0.0.0/0"]
#  }
#  egress {
#    from_port   = 0
#    to_port     = 0
#    protocol    = "-1"
#    cidr_blocks = ["0.0.0.0/0"]
#  }
#}

# --- Task Definition --------------------------------------------
resource "aws_ecs_task_definition" "myapi_task" {
  family                   = "myapi-task"
  requires_compatibilities  = ["FARGATE"]
  network_mode              = "awsvpc" //each task gets its own network interface and IP.
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
      image     = "720283940682.dkr.ecr.us-east-2.amazonaws.com/demo_project_repository:latest",
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
    security_groups = [aws_security_group.alb_sg.id]
    assign_public_ip = true
  }

  depends_on = [aws_iam_role_policy_attachment.ecs_task_exec_attach]
}


