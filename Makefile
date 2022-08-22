# Makefile v1.02

# define variables
aws_profile = myawsprofile
aws_s3_bucket = mys3bucket1
PROJECT_NAME = EvergreenGoldenAmi
EMAIL_FOR_NOTIFICATIONS = me@example.com
VPCID = vpc-12345678
CODEPIPELINE_ARTIFACTSTORE_S3_BUCKET = mycodepipelines3bucket
CODECOMMIT_BRANCH_NAME = main
GOLDEN_AMI_NAME_PREFIX = amazon-linux-two
BASE_AMI_SSM_PARAMETER_NAME = "/${PROJECT_NAME}/base_ami_id"
BASE_AMI_SSM_PARAMETER_DESC = "The id of the base ami that packer will use to create the golden ami"
GOLDEN_AMI_SSM_PARAMETER_NAME = "/${PROJECT_NAME}/latest_custom_ami_id"
GOLDEN_AMI_SSM_PARAMETER_DESC = "The ami id of the latest custom ami"
PACKER_TEMPLATE_FILENAME = amazon-linux_packer-template.json

aws_s3_bucket_prefix = ${PROJECT_NAME}
aws_stack_name = sam-${PROJECT_NAME}

aws_stack_iam_capabilities = CAPABILITY_IAM CAPABILITY_NAMED_IAM
sam_package_template_file = template.yaml
sam_package_output_template_file = package.yaml

CODEPIPELINE_NAME = ${PROJECT_NAME}_Pipeline

CODECOMMIT_REPO_NAME = ${PROJECT_NAME}Repo

CODEBUILD_PROJECT_NAME = ${PROJECT_NAME}_Project
CODEBUILD_CWLOGS_GROUPNAME = CODEBUILD_${PROJECT_NAME}
CODEBUILD_CWLOGS_STREAMNAME = ${PROJECT_NAME}

# set shell to bash
SHELL := bash

.PHONY: all usage package deploy update validate clean

all: usage

usage:
	@echo
	@echo === Help: Command reference ===
	@echo make package - package the sam application and copy it to the s3 bucket at location: [s3://${aws_s3_bucket}/${aws_s3_bucket_prefix}/]
	@echo make deploy  - deploy the packaged sam application to AWS
	@echo make update  - package the sam application and then deploy it to AWS
	@echo make validate - validate template file [${sam_package_template_file}]
	@echo make clean   - delete local [${sam_package_output_template_file}] file
	@echo make delete  - delete the AWS CloudFormation Stack that was created by this AWS SAM template [stackname=${aws_stack_name}]
	@echo
	@echo === Values for configured parameters ===
	@echo aws_profile = ${aws_profile}
	@echo aws_s3_bucket = ${aws_s3_bucket}
	@echo PROJECT_NAME = ${PROJECT_NAME}
	@echo EMAIL_FOR_NOTIFICATIONS = ${EMAIL_FOR_NOTIFICATIONS}
	@echo VPCID = ${VPCID}
	@echo GOLDEN_AMI_NAME_PREFIX = ${GOLDEN_AMI_NAME_PREFIX}
	@echo BASE_AMI_SSM_PARAMETER_NAME = ${BASE_AMI_SSM_PARAMETER_NAME}
	@echo BASE_AMI_SSM_PARAMETER_DESC = ${BASE_AMI_SSM_PARAMETER_DESC}
	@echo GOLDEN_AMI_SSM_PARAMETER_NAME = ${GOLDEN_AMI_SSM_PARAMETER_NAME}
	@echo GOLDEN_AMI_SSM_PARAMETER_DESC = ${GOLDEN_AMI_SSM_PARAMETER_DESC}
	@echo CODEPIPELINE_NAME = ${CODEPIPELINE_NAME}
	@echo CODEPIPELINE_ARTIFACTSTORE_S3_BUCKET = ${CODEPIPELINE_ARTIFACTSTORE_S3_BUCKET}
	@echo CODECOMMIT_REPO_NAME = ${CODECOMMIT_REPO_NAME}
	@echo CODECOMMIT_BRANCH_NAME = ${CODECOMMIT_BRANCH_NAME}
	@echo CODEBUILD_PROJECT_NAME = ${CODEBUILD_PROJECT_NAME}
	@echo CODEBUILD_CWLOGS_GROUPNAME = ${CODEBUILD_CWLOGS_GROUPNAME}
	@echo CODEBUILD_CWLOGS_STREAMNAME = ${CODEBUILD_CWLOGS_STREAMNAME}
	@echo aws_s3_bucket_prefix = ${aws_s3_bucket_prefix}
	@echo aws_stack_name = ${aws_stack_name}
	@echo

package:
	make validate
	sam package --template-file ${sam_package_template_file} --output-template-file ${sam_package_output_template_file} --s3-bucket ${aws_s3_bucket} --s3-prefix ${aws_s3_bucket_prefix} --profile ${aws_profile}

deploy:
	sam deploy \
	--template-file ${sam_package_output_template_file} \
	--stack-name ${aws_stack_name} \
	--capabilities ${aws_stack_iam_capabilities} \
	--profile ${aws_profile} \
	--parameter-overrides \
	'ParameterKey=ProjectName,ParameterValue=${PROJECT_NAME}' \
	'ParameterKey=EmailForNotifications,ParameterValue=${EMAIL_FOR_NOTIFICATIONS}' \
	'ParameterKey=VPCId,ParameterValue=${VPCID}' \
	'ParameterKey=CodePipelinePipelineName,ParameterValue=${CODEPIPELINE_NAME}' \
	'ParameterKey=CodePipelineArtifactStoreS3Bucket,ParameterValue=${CODEPIPELINE_ARTIFACTSTORE_S3_BUCKET}' \
	'ParameterKey=CodeCommitRepoName,ParameterValue=${CODECOMMIT_REPO_NAME}' \
	'ParameterKey=CodeCommitBranchName,ParameterValue=${CODECOMMIT_BRANCH_NAME}' \
	'ParameterKey=CodeBuildProjectName,ParameterValue=${CODEBUILD_PROJECT_NAME}' \
	'ParameterKey=CodeBuildCWLogGroupName,ParameterValue=${CODEBUILD_CWLOGS_GROUPNAME}' \
	'ParameterKey=CodeBuildCWLogStreamName,ParameterValue=${CODEBUILD_CWLOGS_STREAMNAME}' \
	'ParameterKey=AmiNamePrefix,ParameterValue=${GOLDEN_AMI_NAME_PREFIX}' \
	'ParameterKey=PackerTemplateFilename,ParameterValue=${PACKER_TEMPLATE_FILENAME}' \
	'ParameterKey=BaseAmiSSMParameterName,ParameterValue=${BASE_AMI_SSM_PARAMETER_NAME}' \
	'ParameterKey=BaseAmiSSMParameterDesc,ParameterValue=${BASE_AMI_SSM_PARAMETER_DESC}' \
	'ParameterKey=GoldenAmiSSMParameterName,ParameterValue=${GOLDEN_AMI_SSM_PARAMETER_NAME}' \
	'ParameterKey=GoldenAmiSSMParameterDesc,ParameterValue=${GOLDEN_AMI_SSM_PARAMETER_DESC}' \
	--confirm-changeset

update:
	make clean
	make package
	make deploy

validate:
	sam validate --template-file ${sam_package_template_file}

clean:
	rm -f ./${sam_package_output_template_file}

delete:
	aws cloudformation describe-stacks --stack-name ${aws_stack_name}
	@read -p 'Delete CloudFormation Stack:${aws_stack_name}? CTRL+C to abort or any other key to continue.'
	aws cloudformation delete-stack --stack-name ${aws_stack_name}