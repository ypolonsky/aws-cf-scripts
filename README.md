## Description of AWS Cloud Formation templates for deploying Heart Beat Monitor AWS components 

The **healthcheck-master-template.yaml** Cloud Formation template includes all the templates to create all necessary components of the AWS application.

The **input parameters** for the master tamplate are following:

- S3 Bucket Name
- Environment (dev, test, qa, stage, prod)
- VPC Id
- Subnet 1 Id
- Subnet 2 Id
- Default VPC Security Group

The child Cloud Formation templates are depicted in diagram below:

![cf_diagram](../docs/images/CloudFormationTemplates.png)
