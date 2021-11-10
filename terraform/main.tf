terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

#codecommit repository that stores source code

resource "aws_codecommit_repository" "source_repo" {

  repository_name = "pipeline_source_repo"
  description     = "repository for ECS pipeline"

}

#ECR repo to store images for ECS 

resource "aws_ecr_repository" "ecr_repo" {
  name = "pipeline_ecr_repo"
}

#taske and execution role for task defination/cluster

resource "aws_iam_role" "task_defination_role" {
  name        = "task_defination_execution_role"
  description = "Allows ECS tasks to call AWS services on your behalf"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy", ]
}


#create an ECS cluster for pipeline

resource "aws_ecs_cluster" "cluster" {
  name = "pipelineCluster"

}

resource "aws_ecs_task_definition" "defination" {
  family = "pipeline_task"
  container_definitions = jsonencode([
    {
      name   = "webapp"
      image  = "${aws_ecr_repository.ecr_repo.repository_url}"
      memory = 256
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])

  cpu                = 256
  memory             = 512
  execution_role_arn = aws_iam_role.task_defination_role.arn
  network_mode       = "awsvpc"
  requires_compatibilities = [
  "FARGATE"]
  task_role_arn = aws_iam_role.task_defination_role.arn

}
