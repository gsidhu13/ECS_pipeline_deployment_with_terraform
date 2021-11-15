#!/bin/bash
echo enter docker_username 
read username
echo enter docker_username 
read password
aws secretsmanager create-secret \
--name dockerhub \
--description "Docker Hub Secret" \
--secret-string '{"username":"'${username}'","password":"'${password}'"}'

aws codecommit create-repository \
--repository-name pipeline_source_repo \
--repository-description "source pipeline for ecs pipeline" 



