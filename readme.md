## Deploy ECS Fargate containers with AWS CodePipeline

### Quick overview 
 All the resources are implemented with Terraform except the source repo. Source code store in CodeCommit repository, build with CodeDeploy, and then deploy with ECS

### Repo Guide

1. Create source repository and store your docker hub credentials on the secret manager - [bash script](https://github.com/gsidhu13/ECS_pipeline_deployment/blob/dacd16493104f756dc6b2e428d066f90244d2554/secret_manager_n_source_repo.sh#L17)
2. Upload the files to source repository in repo files [directory](https://github.com/gsidhu13/ECS_pipeline_deployment/blob/fc3ad8d7b8d31b49cb31154eccb20d00b5af395f/repo_files) 
   
    Using a console is the easiest and quickest way to upload these files. You could try AWS CLI but it is a bit tricky.
    
    ** Update your account number in buildspec.yml ** 
3. Now provision everything else with terraform [module](https://github.com/gsidhu13/ECS_pipeline_deployment/blob/a901f28d5e1594a87be7fc7690394be16a43087d/terraform)

    ** enter in your account in variable [file](https://github.com/gsidhu13/ECS_pipeline_deployment/blob/a901f28d5e1594a87be7fc7690394be16a43087d/terraform/variables.tf) for account_number variable **

YOUR PIPELINE HAS BEEN CREATED!!

### Clean up 
1. destroy the resources with Terraform 
2. To remove the s3 bucket, source repository, and secret manager secret, run this bash [file](https://github.com/gsidhu13/ECS_pipeline_deployment/blob/3d4169cf242e12ada9cb3034802dfde93eed93c4/cleanup/del_bucket_repo_n_secrets.sh)
   
Open up an issue if you encounter any problems.
