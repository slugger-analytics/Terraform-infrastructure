# GitHub Actions OIDC Provider and Deploy Role
# Allows GitHub Actions in JHU-Lineup-Optimization repos to deploy to AWS

# Reuse the existing GitHub OIDC provider already in this AWS account
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# IAM Role that GitHub Actions assumes via OIDC
resource "aws_iam_role" "github_actions_deploy" {
  name = "lineup-optim-github-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:JHU-Lineup-Optimization/web-app:ref:refs/heads/main",
              "repo:JHU-Lineup-Optimization/web-server:ref:refs/heads/main"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Component   = var.component_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Policy: ECR push access
resource "aws_iam_role_policy" "ecr_push" {
  name = "lineup-optim-ecr-push"
  role = aws_iam_role.github_actions_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = [
          aws_ecr_repository.web_app.arn,
          aws_ecr_repository.web_server.arn
        ]
      }
    ]
  })
}

# Policy: Lambda update access
resource "aws_iam_role_policy" "lambda_deploy" {
  name = "lineup-optim-lambda-deploy"
  role = aws_iam_role.github_actions_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration"
        ]
        Resource = [
          aws_lambda_function.web_app.arn,
          aws_lambda_function.web_server.arn
        ]
      }
    ]
  })
}

# Output the role ARN — this is what you set as AWS_DEPLOY_ROLE_ARN in GitHub secrets
output "github_deploy_role_arn" {
  description = "IAM role ARN for GitHub Actions — set this as AWS_DEPLOY_ROLE_ARN in both repos' GitHub secrets"
  value       = aws_iam_role.github_actions_deploy.arn
}
