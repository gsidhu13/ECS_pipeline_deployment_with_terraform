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
#create task defination 

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
#grab default vpc and create security group 

resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}
resource "aws_security_group" "ecs_pipeline_sg" {
  name   = "sg_ecs_pipeline"
  vpc_id = aws_default_vpc.default.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]

  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]

  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

#default subnets 
resource "aws_default_subnet" "default_az1" {
  availability_zone = "us-east-1a"

}
resource "aws_default_subnet" "default_az2" {
  availability_zone = "us-east-1b"

}
#Create service

resource "aws_ecs_service" "pipeline_service" {
  name = "pipeline_service"
  cluster                            = aws_ecs_cluster.cluster.arn
  enable_ecs_managed_tags            = true
  deployment_maximum_percent         = "200"
  deployment_minimum_healthy_percent = "100"
  desired_count                      = 2
  launch_type                        = "FARGATE"
  network_configuration {
    subnets          = ["${aws_default_subnet.default_az1.id}", "${aws_default_subnet.default_az2.id}"]
    security_groups  = ["${aws_security_group.ecs_pipeline_sg.id}"]
    assign_public_ip = "true"
  }
  scheduling_strategy = "REPLICA"
  task_definition     = aws_ecs_task_definition.defination.arn

}

