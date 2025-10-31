provider "aws" {
  region = "us-east-1"
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

