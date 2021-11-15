variable "source_repo_name" {
  type        = string
  description = "declaring codeCommit Repo name"
  default     = "pipeline_source_repo"
}
variable "account_number" {
  type    = number
  default = "your account #"

}
variable "cluster_name" {
  type    = string
  default = "ecs_cluster"

}
variable "bucket_name" {
  type    = string
  default = "codepipeline-gsingh"

}
#will need for buildspec file 
variable "ecr_repo_name" {
  type    = string
  default = "ecs_pipeline"

}
variable "codeBuild_loggroup" {
  type    = string
  default = "codebuild_ecs_group"

}
variable "codeBuild_streamgroup" {
  type    = string
  default = "codebuild_ecs_stream"
}

variable "secret_manager_name" {
  type    = string
  default = "dockerhub"

}