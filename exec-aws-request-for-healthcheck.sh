#!/bin/bash

if (($# < 1)); then
  account="107424568411"
else
  account=$1
fi
if (($# < 2)); then
  tier=dev
else
  tier=$2
fi

echo -e "Deploy CF stack with Lambda HealthCheck"

s3bucket="cf-templates-$account-us-east-1"

request_template="app-request-healthcheck.yaml"

# Create s3 bucket if it doesn't exist
aws s3api create-bucket --bucket "$s3bucket" --region us-east-1
aws s3 cp "$request_template" "s3://$s3bucket"


sns_alarm_topic=$(aws cloudformation describe-stacks --stack-name "healthcheck-${tier}" --query "Stacks[0].Outputs[?OutputKey=='SnsHealthCheckAlarmTopic'].OutputValue | [0]" | sed -e 's/^"//' -e 's/"$//')
lambda_arn=$(aws cloudformation describe-stacks --stack-name "healthcheck-${tier}" --query "Stacks[0].Outputs[?OutputKey=='LambdaHealthCheckArn'].OutputValue | [0]" | sed -e 's/^"//' -e 's/"$//')
log_group_name=$(aws cloudformation describe-stacks --stack-name "healthcheck-${tier}" --query "Stacks[0].Outputs[?OutputKey=='LogGroupHealthCheckName'].OutputValue | [0]" | sed -e 's/^"//' -e 's/"$//')

if (! aws cloudformation describe-stacks --stack-name "healthcheck-request-${tier}")
then
  aws cloudformation create-stack --stack-name "healthcheck-request-${tier}" --template-url "https://${s3bucket}.s3.amazonaws.com/${request_template}" --parameters \
          ParameterKey=SnsHealthCheckAlarmTopic,ParameterValue=$sns_alarm_topic \
          ParameterKey=LambdaFunctionHealthCheckArn,ParameterValue=$lambda_arn \
          ParameterKey=LogGroupHealthCheckName,ParameterValue=$log_group_name
  echo -n "Creating stack..."
else
  aws cloudformation update-stack --stack-name "healthcheck-request-${tier}" --template-url "https://${s3bucket}.s3.amazonaws.com/${request_template}" --parameters \
          ParameterKey=SnsHealthCheckAlarmTopic,ParameterValue=$sns_alarm_topic \
          ParameterKey=LambdaFunctionHealthCheckArn,ParameterValue=$lambda_arn \
          ParameterKey=LogGroupHealthCheckName,ParameterValue=$log_group_name
fi

  stackStatus=null
  while [ ${stackStatus} != 'CREATE_COMPLETE' ] && [ ${stackStatus} != 'ROLLBACK_COMPLETE' ]; do
      sleep 2s
      echo -n "."
      stackStatus=$(aws cloudformation describe-stacks --stack-name "healthcheck-request-${tier}" --query "Stacks[0].StackStatus" | sed -e 's/^"//' -e 's/"$//')
  done
  if [ ${stackStatus} = 'CREATE_COMPLETE' ]
  then
    echo -e "\nHeart Beat Monitor Events and Alarms have been created successfully."
  else
    echo -e "\nFAILED: Heart Beat Monitor Events and Alarms creation.  Please, check the CloudFormation stack in AWS Console."
  fi
