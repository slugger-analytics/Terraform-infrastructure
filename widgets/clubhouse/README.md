# ClubhouseWidget Terraform Infrastructure

Terraform configuration for deploying ClubhouseWidget to AWS Lambda with ALB routing.

## Architecture

```
ALB (slugger-alb)
  └── /widgets/clubhouse/* → Lambda (widget-clubhouse)
                                └── Aurora PostgreSQL (alpb-1)
```

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.0.0
3. Docker (for building Lambda images)
4. Existing SLUGGER infrastructure (VPC, ALB, Aurora)

## Resources Created

- **ECR Repository**: `widget-clubhouse` - Docker image storage
- **Lambda Function**: `widget-clubhouse` - Express.js API + React SPA
- **IAM Role**: `lambda-widget-clubhouse` - Lambda execution role
- **CloudWatch Log Group**: `/aws/lambda/widget-clubhouse`
- **ALB Target Group**: `tg-widget-clubhouse`
- **ALB Listener Rules**: Priority 100 for `/widgets/clubhouse/*`

## Deployment

### First-time Setup

```bash
cd infrastructure/widgets/clubhouse

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply (creates ECR, Lambda placeholder, ALB rules)
terraform apply
```

### Push Initial Docker Image

After Terraform creates the ECR repository, push an initial image:

```bash
cd ClubhouseWidget

# Build frontend
cd frontend && npm ci && npm run build
cp -r dist/* ../lambda/public/

# Build Lambda
cd ../lambda && npm ci && npm run build

# Build and push Docker image
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 746669223415.dkr.ecr.us-east-2.amazonaws.com

docker build --platform linux/arm64 -t widget-clubhouse .
docker tag widget-clubhouse:latest 746669223415.dkr.ecr.us-east-2.amazonaws.com/widget-clubhouse:latest
docker push 746669223415.dkr.ecr.us-east-2.amazonaws.com/widget-clubhouse:latest

# Update Lambda to use the new image
aws lambda update-function-code \
  --function-name widget-clubhouse \
  --image-uri 746669223415.dkr.ecr.us-east-2.amazonaws.com/widget-clubhouse:latest
```

## Configuration

### Environment Variables

The Lambda function uses these environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Internal port | `8080` |
| `BASE_PATH` | URL base path | `/widgets/clubhouse` |
| `COGNITO_USER_POOL_ID` | Cognito User Pool | `us-east-2_tG7IQQ6G7` |
| `COGNITO_CLIENT_ID` | Cognito Client ID | (set via variable) |
| `DB_HOST` | Aurora endpoint | `alpb-1.cluster-...` |
| `DB_NAME` | Database name | `slugger` |
| `DB_USER` | Database user | `slugger` |
| `DB_PASSWORD` | Database password | (from SSM at runtime) |

### Database Password

Store the database password in SSM Parameter Store:

```bash
aws ssm put-parameter \
  --name "/slugger/db/password" \
  --value "YOUR_PASSWORD" \
  --type SecureString
```

Then update the Lambda to read from SSM at runtime.

## VPC Configuration

ClubhouseWidget Lambda runs inside the VPC to access Aurora. This requires:

1. **Private Subnets**: Lambda deployed to private subnets
2. **Security Group**: Uses ECS tasks security group (allows Aurora access)
3. **VPC Endpoints** (optional but recommended):
   - `com.amazonaws.us-east-2.logs` - CloudWatch Logs
   - `com.amazonaws.us-east-2.ssm` - SSM Parameter Store

Without VPC Endpoints, Lambda cannot:
- Write logs to CloudWatch
- Read parameters from SSM

## Outputs

| Output | Description |
|--------|-------------|
| `lambda_function_arn` | Lambda ARN |
| `lambda_function_name` | Lambda name |
| `ecr_repository_url` | ECR repository URL |
| `target_group_arn` | ALB target group ARN |
| `alb_path` | ALB path pattern |
| `widget_url` | Full widget URL |

## Troubleshooting

### Lambda Not Responding

1. Check CloudWatch Logs: `/aws/lambda/widget-clubhouse`
2. Verify VPC Endpoints exist for CloudWatch Logs
3. Check security group allows outbound to Aurora (port 5432)

### Database Connection Errors

1. Verify Aurora security group allows inbound from ECS tasks SG
2. Check DB_PASSWORD environment variable is set
3. Test connection from another Lambda/EC2 in same VPC

### ALB 502 Errors

1. Lambda timeout may be too short (increase to 30s)
2. Check Lambda has correct VPC configuration
3. Verify ECR image was pushed successfully

## Cost Estimate

| Resource | Monthly Cost |
|----------|--------------|
| Lambda (512MB, ~100k invocations) | ~$2-5 |
| ECR Storage | ~$1 |
| CloudWatch Logs | ~$1-2 |
| VPC Endpoints (if created) | ~$14 |
| **Total** | **~$4-22** |
