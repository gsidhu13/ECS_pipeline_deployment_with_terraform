output "ecr_repo_arn" {
  value = aws_ecr_repository.ecr_repo.arn
}
output "container_name" {
value = aws_ecs_task_definition.defination.container_definitions
  
}