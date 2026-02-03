# Main Terraform Configuration for ClubhouseWidget Lambda Deployment

locals {
  widget_name = var.widget_name
  common_tags = {
    Project     = "slugger"
    Component   = "widget-${local.widget_name}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# ECR Repository
# =============================================================================

resource "aws_ecr_repository" "widget" {
  name                 = "widget-${local.widget_name}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

# =============================================================================
# IAM Role and Policy for Lambda
# =============================================================================

resource "aws_iam_role" "lambda_widget" {
  name = "lambda-widget-${local.widget_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "lambda_widget" {
  name = "lambda-widget-${local.widget_name}-policy"
  role = aws_iam_role.lambda_widget.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/widget-${local.widget_name}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/slugger/*"
      }
    ]
  })
}

# =============================================================================
# CloudWatch Log Group
# =============================================================================

resource "aws_cloudwatch_log_group" "lambda_widget" {
  name              = "/aws/lambda/widget-${local.widget_name}"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

# =============================================================================
# Lambda Function
# =============================================================================

resource "aws_lambda_function" "widget" {
  function_name = "widget-${local.widget_name}"
  role          = aws_iam_role.lambda_widget.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.widget.repository_url}:latest"

  # Use ARM64 (Graviton2) for better price-performance
  architectures = ["arm64"]

  memory_size = var.memory_size
  timeout     = var.timeout

  vpc_config {
    subnet_ids         = data.aws_subnets.private.ids
    security_group_ids = [data.aws_security_group.ecs_tasks.id]
  }

  environment {
    variables = {
      PORT                 = "8080"
      BASE_PATH            = "/widgets/${local.widget_name}"
      COGNITO_USER_POOL_ID = var.cognito_user_pool_id
      COGNITO_CLIENT_ID    = var.cognito_client_id
      DB_HOST              = var.db_host
      DB_NAME              = var.db_name
      DB_USER              = var.db_user
      # DB_PASSWORD should be set via SSM Parameter Store at runtime
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_widget,
    aws_iam_role_policy.lambda_widget
  ]

  tags = local.common_tags
}

# =============================================================================
# ALB Target Group and Routing
# =============================================================================

resource "aws_lb_target_group" "lambda_widget" {
  name        = "tg-widget-${local.widget_name}"
  target_type = "lambda"

  tags = local.common_tags
}

resource "aws_lambda_permission" "alb" {
  statement_id  = "AllowALBInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.widget.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.lambda_widget.arn
}

resource "aws_lb_target_group_attachment" "lambda_widget" {
  target_group_arn = aws_lb_target_group.lambda_widget.arn
  target_id        = aws_lambda_function.widget.arn
  depends_on       = [aws_lambda_permission.alb]
}

# ALB Listener Rule (HTTPS) - Priority 100 (before flashcard at 200)
resource "aws_lb_listener_rule" "widget_https" {
  listener_arn = data.aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda_widget.arn
  }

  condition {
    path_pattern {
      values = ["/widgets/${local.widget_name}/*", "/widgets/${local.widget_name}"]
    }
  }

  tags = local.common_tags
}

# ALB Listener Rule (HTTP)
resource "aws_lb_listener_rule" "widget_http" {
  listener_arn = data.aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda_widget.arn
  }

  condition {
    path_pattern {
      values = ["/widgets/${local.widget_name}/*", "/widgets/${local.widget_name}"]
    }
  }

  tags = local.common_tags
}
