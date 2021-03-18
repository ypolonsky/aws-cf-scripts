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

tmaster="healthcheck-master.template.yaml"
tec2sg="healthcheck-ec2-security-groups.template.yaml"
tec2vpce="healthcheck-ec2-vpcendpoints.template.yaml"
tiamlambda="healthcheck-iam-lambda-role.template.yaml"
tlambda="healthcheck-lambda-function.template.yaml"

# Create s3 bucket if it doesn't exist
aws s3api create-bucket --bucket "$s3bucket" --region us-east-1
aws s3 cp "$tmaster" "s3://$s3bucket"
aws s3 cp "$tec2sg" "s3://$s3bucket"
aws s3 cp "$tec2vpce" "s3://$s3bucket"
aws s3 cp "$tiamlambda" "s3://$s3bucket"
aws s3 cp "$tlambda" "s3://$s3bucket"

#subnet1=$(aws cloudformation describe-stacks --stack-name ec2-serverless --query "Stacks[0].Outputs[?OutputKey=='SubnetId'].OutputValue | [0]" | sed -e 's/^"//' -e 's/"$//')
subnet1=$(aws ec2 describe-subnets --query "Subnets[?AvailabilityZone=='us-east-1a'].SubnetId | [0]" | sed -e 's/^"//' -e 's/"$//')
echo -e "Subnet 1 is $subnet1"
subnet2=$(aws ec2 describe-subnets --query "Subnets[?AvailabilityZone=='us-east-1b'].SubnetId | [0]" | sed -e 's/^"//' -e 's/"$//')
echo -e "Subnet 2 is $subnet2"
sg=$(aws ec2 describe-security-groups --query "SecurityGroups[?GroupName=='default'].GroupId | [0]" | sed -e 's/^"//' -e 's/"$//')
echo -e "Security Group is $sg"
vpcid=$(aws ec2 describe-vpcs --query Vpcs[0].VpcId | sed -e 's/^"//' -e 's/"$//')
echo VPC id = $vpcid

aws cloudformation create-stack --stack-name "healthcheck-${tier}" --template-url "https://${s3bucket}.s3.amazonaws.com/${tmaster}" --parameters \
        ParameterKey=S3Bucket,ParameterValue=$s3bucket \
        ParameterKey=Environment,ParameterValue=$tier \
        ParameterKey=VpcId,ParameterValue=$vpcid \
        ParameterKey=VpcSubnetId1,ParameterValue=$subnet1 \
        ParameterKey=VpcSubnetId2,ParameterValue=$subnet2 \
        ParameterKey=VpcDefaultSgId,ParameterValue=$sg \
        --capabilities CAPABILITY_NAMED_IAM

stackStatus=$(aws cloudformation describe-stacks --stack-name "healthcheck-${tier}" --query "Stacks[0].StackStatus" | sed -e 's/^"//' -e 's/"$//')
echo -e "Start creating stack.  Status - $stackStatus"
echo -n "Creating stack..."
while [ ${stackStatus} != 'CREATE_COMPLETE' ] && [ ${stackStatus} != 'ROLLBACK_COMPLETE' ]; do
    sleep 2s
    echo -n "."
    stackStatus=$(aws cloudformation describe-stacks --stack-name "healthcheck-${tier}" --query "Stacks[0].StackStatus" | sed -e 's/^"//' -e 's/"$//')
done
if [ ${stackStatus} = 'CREATE_COMPLETE' ]
then
  echo -e "\nHeart Beat Monitor Events and Alarms have been created successfully."
else
  echo -e "\nFAILED: Heart Beat Monitor Events and Alarms creation.  Please, check the CloudFormation stack in AWS Console."
fi

lambdafunction=null
while [ ${lambdafunction} == null ]; do
    sleep 2s
    echo -n "."
    lambdafunction=$(aws cloudformation describe-stacks --stack-name "healthcheck-${tier}" --query "Stacks[0].Outputs[?OutputKey=='LambdaHealthCheckId'].OutputValue | [0]")
done
echo -e "\nLambda function has been created.  $lambdafunction"
