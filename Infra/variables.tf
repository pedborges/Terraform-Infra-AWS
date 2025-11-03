variable "app_runner_service_name" {
  type = string
   default = "mydemoproject-app"
}
variable "repository_name" {
    type = string
  default = "demo_project_repository"
}

variable "image_tag" {
    type = string
  default = "latest"
}
variable "ecs_public_endpoint" {
  type        = string
  default = "Public endpoint (IP or DNS) of ECS Fargate API"
}