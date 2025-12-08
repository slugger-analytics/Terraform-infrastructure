# Batter Widget Lambda Deployment

This Terraform configuration deploys the Batter Widget (`baseball_flashcard`) as an AWS Lambda function behind the existing SLUGGER Application Load Balancer.

## Overview

The deployment creates:
- ECR repository for the widget container image
- Lambda function with VPC integration
- IAM role and policy for Lambda execution
- CloudWatch log group for monitoring
- ALB target group and listener rules for routing

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0.0
- Docker for building container images
- Access to the SLUGGER AWS account (746669223415)

## Directory Structure

```
infrastructure/widgets/flashcard/
├── main.tf           # Primary resources (Lambda, ECR, IAM, ALB routing)
├── data.tf           # Data sources for existing infrastructure
├── variables.tf      # Input variables
├── outputs.tf        # Output values
├── providers.tf      # AWS provider configuration
└── README.md         # This file
```

## Deployment Steps

### 1. Initialize Terraform

```bash
cd infrastructure/widgets/flashcard
terraform init
```

### 2. Review the Plan

```bash
terraform plan
```

Verify that only new resources are created and no existing infrastructure is modified.

### 3. Apply Configuration

```bash
terraform apply
```

Note: The Lambda function will fail initially until a container image is pushed to ECR.


### 4. Build and Push Docker Image

```bash
# Navigate to widget source
cd baseball_flashcard

# Build the container
docker build -t widget-flashcard .

# Authenticate with ECR
aws ecr get-login-password --region us-east-2 | \
  docker login --username AWS --password-stdin 746669223415.dkr.ecr.us-east-2.amazonaws.com

# Tag with git commit SHA
docker tag widget-flashcard:latest \
  746669223415.dkr.ecr.us-east-2.amazonaws.com/widget-flashcard:$(git rev-parse --short HEAD)

# Push to ECR
docker push 746669223415.dkr.ecr.us-east-2.amazonaws.com/widget-flashcard:$(git rev-parse --short HEAD)
```

### 5. Update Lambda Function

```bash
aws lambda update-function-code \
  --function-name widget-flashcard \
  --image-uri 746669223415.dkr.ecr.us-east-2.amazonaws.com/widget-flashcard:$(git rev-parse --short HEAD)
```

### 6. Validate Deployment

```bash
# Health check
curl https://[ALB-DNS]/widgets/flashcard/api/health

# API endpoint
curl "https://[ALB-DNS]/widgets/flashcard/api/teams/range?startDate=20240517&endDate=20240519"

# Static files
curl https://[ALB-DNS]/widgets/flashcard/
```

## Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region for deployment | `us-east-2` |
| `widget_name` | Widget identifier | `flashcard` |
| `environment` | Deployment environment | `production` |
| `memory_size` | Lambda memory in MB | `512` |
| `timeout` | Lambda timeout in seconds | `30` |
| `log_retention_days` | CloudWatch log retention | `14` |
| `slugger_api_url` | SLUGGER API Gateway URL | (see variables.tf) |

## Outputs

| Output | Description |
|--------|-------------|
| `lambda_function_arn` | ARN of the Lambda function |
| `ecr_repository_url` | URL for pushing container images |
| `alb_path` | ALB path pattern for the widget |
| `cloudwatch_log_group` | Log group for monitoring |

## Existing Infrastructure References

This configuration references existing SLUGGER infrastructure via data sources:

- **VPC**: `vpc-030c8d613fc104199`
- **ALB**: `slugger-alb`
- **ALB Security Group**: `sg-0c35c445084f80855`
- **ECS Security Group**: `sg-0c985525970ae7372` (used for Lambda VPC access)
- **Private Subnets**: Filtered by `Type=private` tag

## Resource Tagging

All resources are tagged with:
- `Project`: slugger
- `Component`: widget-flashcard
- `Environment`: production
- `ManagedBy`: terraform

## Troubleshooting

### Lambda Cold Starts
Phase 0 accepts cold starts as a known limitation. EventBridge warmers will be added in Phase 1.

### VPC Connectivity Issues
Ensure the Lambda function has access to the internet via NAT Gateway for external API calls.

### Image Push Failures
Verify ECR authentication and that the repository exists before pushing.

## Phase 0 Scope

This deployment is part of Phase 0 (Tactical Deployment). The following are deferred to later phases:

- **Phase 1**: EventBridge warmers, SSM parameters, dedicated Lambda security group
- **Phase 2**: CI/CD automation, security scanning
