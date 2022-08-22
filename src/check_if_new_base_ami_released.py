import os
import json
import boto3
from dateutil import parser

aws_region = os.environ['REGION']
ssm_parameter_name_base_ami_id = os.environ['SSM_PARAMETER_NAME_BASE_AMI_ID']
codepipeline_pipeline_name = os.environ['CODEPIPELINE_PIPELINE_NAME']

## this function finds the latest available ami from Amazon that matches the filter criteria. This ami will be used as the base for the custom amis
def find_latest_available_base_ami():
    ec2_client = boto3.client('ec2', aws_region)

    response = ec2_client.describe_images(
        Filters=[
            {
                'Name': 'name',
                'Values': ['amzn2-ami-kernel-*-hvm-*']
            },
            {
                'Name': 'architecture',
                'Values': ['x86_64']
            },
            {
                'Name': 'owner-alias',
                'Values': ['amazon']
            },
            {
                'Name': 'state',
                'Values': ['available']
            },            
            {
                'Name': 'virtualization-type',
                'Values': ['hvm']
            },
            {
                'Name': 'root-device-type',
                'Values': ['ebs']
            }
        ]
    )

    latest_ami = None

    for image in response['Images']:
        if not latest_ami:
            latest_ami = image
            continue

        if parser.parse(image['CreationDate']) > parser.parse(latest_ami['CreationDate']):
            latest_ami = image
        
    return latest_ami['ImageId']

## this function returns the ami that is being used as the base for the custom amis
def get_latest_known_base_ami():
    ssm_client = boto3.client('ssm', aws_region)

    response = ssm_client.get_parameter(
        Name = ssm_parameter_name_base_ami_id,
        WithDecryption=False
    )
    print(f"response: {response}")

    return response['Parameter']['Value']

## this function checks if a new base ami was released. If yes, AWS SSM Parameter Store Parameter is updated and
## AWS CodePipeline pipeline is triggered to build a new custom ami using the new base ami
def find_if_new_base_ami_was_released():
    latest_available_base_ami = find_latest_available_base_ami()  # this is the latest base ami available from AWS
    latest_known_base_ami = get_latest_known_base_ami()  # this is the latest base ami that we know about

    return_msg = ""

    if latest_known_base_ami != latest_available_base_ami:
        print(f">>new base ami has been released. AWS SSM Parameter Store Parameter value will be updated now")

        ssm_client = boto3.client('ssm', aws_region)
        ssm_response = ssm_client.put_parameter(
            Name = ssm_parameter_name_base_ami_id,
            Value = latest_available_base_ami,
            Overwrite = True
        )

        print(f"Response from updating AWS SSM Parameter Store parameter for base ami: {ssm_response}")

        # check if the AWS SSM Parameter Store Parameter update operation was successful. If yes then
        # trigger the AWS CodePipeline pipeline to create a new custom ami using the latest base ami
        if ssm_response['ResponseMetadata']['HTTPStatusCode'] == 200:
            print('>>operation to update AWS SSM Parameter Store parameter for base ami was successful')
            print('>>triggering AWS Codepipeline pipeline to create new custom ami using new base ami')

            codepipeline_client = boto3.client('codepipeline', aws_region)
            
            codepipeline_response = codepipeline_client.start_pipeline_execution(
                name = codepipeline_pipeline_name
            )

            print(f">>response from starting AWS Codepipeline pipeline: {codepipeline_response}")

            return_msg = "New base ami found. SSM Parameter Store parameter vaule updated successfully."

            if codepipeline_response['ResponseMetadata']['HTTPStatusCode'] == 200:
                return_msg += " AWS CodePipeline[" + codepipeline_pipeline_name + "] successfully triggered"
            else:
                return_msg += " Error triggering AWS CodePipeline[" + codepipeline_pipeline_name + "]. Full error message:" + codepipeline_response
        else:
            print('>>error updating AWS SSM Parameter Store parameter for base ami. Check response above')
            return_msg += "New base ami found. Error updating SSM Parameter Store parameter vaule. Full error message:" + ssm_response
    else:
        print(f">>no new base ami found")
        return_msg = "No new base ami found"

    return return_msg

def lambda_handler(event, context):
    response = find_if_new_base_ami_was_released()

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": response,
        }),
    }