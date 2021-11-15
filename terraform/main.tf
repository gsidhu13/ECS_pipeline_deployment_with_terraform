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

#ECR repo to store images for ECS 
resource "aws_ecr_repository" "ecr_repo" {
  name = var.ecr_repo_name
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
  name = var.cluster_name

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
#grab default vpc and create security group for this cluster
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
  name                               = "pipeline_service"
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

#pipeline service role

resource "aws_iam_role" "codepipeline_service_role" {
  name = "CodePipeline_service_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      },
    ]
  })
}

#policy for codepipeline service role

resource "aws_iam_role_policy" "pipeline_polciy" {
  role = aws_iam_role.codepipeline_service_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "iam:PassRole"
        ],
        Resource = "*",
        Effect   = "Allow",
        Condition = {
          StringEqualsIfExists = {
            "iam:PassedToService" : [
              "cloudformation.amazonaws.com",
              "elasticbeanstalk.amazonaws.com",
              "ec2.amazonaws.com",
              "ecs-tasks.amazonaws.com"
            ]
          }
        }
      },
      {
        Action = [
          "codecommit:CancelUploadArchive",
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:GetRepository",
          "codecommit:GetUploadArchiveStatus",
          "codecommit:UploadArchive"
        ],
        Resource = "*",
        Effect   = "Allow"
      },
      {
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision"
        ],
        Resource = "*",
        Effect   = "Allow"
      },
      {
        Action = [
          "codestar-connections:UseConnection"
        ],
        Resource = "*",
        Effect   = "Allow"
      },
      {
        Action = [
          "elasticbeanstalk:*",
          "ec2:*",
          "elasticloadbalancing:*",
          "autoscaling:*",
          "cloudwatch:*",
          "s3:*",
          "sns:*",
          "cloudformation:*",
          "rds:*",
          "sqs:*",
          "ecs:*"
        ],
        Resource = "*",
        Effect   = "Allow"
      },
      {
        Action = [
          "lambda:InvokeFunction",
          "lambda:ListFunctions"
        ],
        Resource = "*",
        Effect   = "Allow"
      },
      {
        Action = [
          "opsworks:CreateDeployment",
          "opsworks:DescribeApps",
          "opsworks:DescribeCommands",
          "opsworks:DescribeDeployments",
          "opsworks:DescribeInstances",
          "opsworks:DescribeStacks",
          "opsworks:UpdateApp",
          "opsworks:UpdateStack"
        ],
        Resource = "*",
        Effect   = "Allow"
      },
      {
        Action = [
          "cloudformation:CreateStack",
          "cloudformation:DeleteStack",
          "cloudformation:DescribeStacks",
          "cloudformation:UpdateStack",
          "cloudformation:CreateChangeSet",
          "cloudformation:DeleteChangeSet",
          "cloudformation:DescribeChangeSet",
          "cloudformation:ExecuteChangeSet",
          "cloudformation:SetStackPolicy",
          "cloudformation:ValidateTemplate"
        ],
        Resource = "*",
        Effect   = "Allow"
      },
      {
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
          "codebuild:BatchGetBuildBatches",
          "codebuild:StartBuildBatch"
        ],
        Resource = "*",
        Effect   = "Allow"
      },
      {
        Effect = "Allow",
        Action = [
          "devicefarm:ListProjects",
          "devicefarm:ListDevicePools",
          "devicefarm:GetRun",
          "devicefarm:GetUpload",
          "devicefarm:CreateUpload",
          "devicefarm:ScheduleRun"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "servicecatalog:ListProvisioningArtifacts",
          "servicecatalog:CreateProvisioningArtifact",
          "servicecatalog:DescribeProvisioningArtifact",
          "servicecatalog:DeleteProvisioningArtifact",
          "servicecatalog:UpdateProduct"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "cloudformation:ValidateTemplate"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ecr:DescribeImages"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "states:DescribeExecution",
          "states:DescribeStateMachine",
          "states:StartExecution"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "appconfig:StartDeployment",
          "appconfig:StopDeployment",
          "appconfig:GetDeployment"
        ],
        Resource = "*"
      }
    ]

  })

}

#codebuild role for ECS

resource "aws_iam_role" "codebuild_service_role" {
  name        = "Codebuild_service_role"
  description = "codeBuild role to make changes on ECS"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser", ]

}
#codebuild service role policy

resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_service_role.id
  name = "codebuild_policy_pipeline"
  policy = jsonencode(
    {
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Resource = [
            "arn:aws:logs:us-east-1:${var.account_number}:log-group:${var.codeBuild_loggroup}",
            "arn:aws:logs:us-east-1:${var.account_number}:log-group:${var.codeBuild_loggroup}:*"
          ],
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
        },
        {
          Effect = "Allow",
          Resource = [
            "arn:aws:s3:::${var.bucket_name}*"
          ],
          Action = [
            "s3:PutObject",
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:GetBucketAcl",
            "s3:GetBucketLocation"
          ]
        },
        {
          Effect = "Allow",
          Resource = [
            "arn:aws:codecommit:us-east-1:${var.account_number}:${var.source_repo_name}"
          ],
          Action = [
            "codecommit:GitPull"
          ]
        },
        {
          Effect = "Allow",
          Action = [
            "codebuild:CreateReportGroup",
            "codebuild:CreateReport",
            "codebuild:UpdateReport",
            "codebuild:BatchPutTestCases",
            "codebuild:BatchPutCodeCoverages"
          ],
          Resource = [
            "arn:aws:codebuild:us-east-1:${var.account_number}:report-group/*"
          ]
        },
        {

          Effect = "Allow",
          Action = [
            "secretsmanager:GetSecretValue"
          ],
          Resource = [
            "${data.aws_secretsmanager_secret.name.arn}"
          ]
        }
      ]
    }
  )
}

#docker's credentials store secre manager

data "aws_secretsmanager_secret" "name" {
  name = var.secret_manager_name
}

#codebuild project for pipeline

resource "aws_codebuild_project" "codebuild_project" {
  name = "ecs_codebuild"
  artifacts {
    type = "NO_ARTIFACTS"
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    environment_variable {

      name  = "DOCKERHUB_USERNAME"
      type  = "SECRETS_MANAGER"
      value = "dockerhub:username"
    }
    environment_variable {

      name  = "DOCKERHUB_PASSWORD"
      type  = "SECRETS_MANAGER"
      value = "dockerhub:password"
    }
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    privileged_mode = true
    type            = "LINUX_CONTAINER"
  }

  source {
    type = "CODECOMMIT"
    git_submodules_config {
      fetch_submodules = true
    }
    location = "https://git-codecommit.us-east-1.amazonaws.com/v1/repos/${var.source_repo_name}"
  }
  build_timeout = 5
  description   = "project for ecs pipeline"
  service_role  = aws_iam_role.codebuild_service_role.arn
  logs_config {
    cloudwatch_logs {
      group_name  = var.codeBuild_loggroup
      status      = "ENABLED"
      stream_name = var.codeBuild_streamgroup

    }
  }

}
#pipeline artifact bucket 
resource "aws_s3_bucket" "codePipeline_bucket" {
  bucket = var.bucket_name
}

#create pipeline 

resource "aws_codepipeline" "pipeline" {
  name     = var.ecr_repo_name
  role_arn = aws_iam_role.codepipeline_service_role.arn
  artifact_store {
    location = aws_s3_bucket.codePipeline_bucket.bucket
    type     = "S3"
  }
  stage {
    name = "codecommit_source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        RepositoryName       = var.source_repo_name
        BranchName           = "main"
        PollForSourceChanges = true
      }
    }
  }
  stage {
    name = "build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration = {
        ProjectName = aws_codebuild_project.codebuild_project.id

      }

    }
  }
  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["build_output"]
      configuration = {
        ClusterName = var.cluster_name
        ServiceName = aws_ecs_service.pipeline_service.name

      }
    }
  }
}


