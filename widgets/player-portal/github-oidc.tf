# GitHub Actions OIDC Deploy Role for Player Portal
# Allows GitHub Actions in the slugger-player-portal repo to push images to ECR
# and update Lambda function code — no long-lived AWS credentials needed.
#
# GitHub org: slugger-analytics (from git remote get-url origin)

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "github_actions_deploy" {
  name = "player-portal-github-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
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
            "repo:slugger-analytics/slugger-player-portal:ref:refs/heads/main"
          ]
        }
      }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "ecr_push" {
  name = "player-portal-ecr-push"
  role = aws_iam_role.github_actions_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
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
          aws_ecr_repository.web.arn,
          aws_ecr_repository.api.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_deploy" {
  name = "player-portal-lambda-deploy"
  role = aws_iam_role.github_actions_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "lambda:UpdateFunctionCode",
        "lambda:GetFunction",
        "lambda:GetFunctionConfiguration"
      ]
      Resource = [
        aws_lambda_function.web.arn,
        aws_lambda_function.api.arn,
        aws_lambda_function.sync.arn
      ]
    }]
  })
}

resource "aws_iam_role_policy" "ssm_read_ci" {
  name = "player-portal-ssm-read-ci"
  role = aws_iam_role.github_actions_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["ssm:GetParameter"]
      Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/slugger/player-portal/api-url-public"
    }]
  })
}

# After terraform apply, set this ARN as AWS_DEPLOY_ROLE_ARN in the
# slugger-player-portal GitHub repository secrets
output "github_deploy_role_arn" {
  description = "Set as AWS_DEPLOY_ROLE_ARN in the slugger-player-portal GitHub repo secrets"
  value       = aws_iam_role.github_actions_deploy.arn
}
