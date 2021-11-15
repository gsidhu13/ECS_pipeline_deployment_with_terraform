#!/bin/bash
aws s3 rm s3://codepipeline-gsingh --recursive

aws codecommit delete-repository \
--repository-name pipeline_source_repo

aws secretsmanager delete-secret \
--secret-id dockerhub \
--recovery-window-in-days 7