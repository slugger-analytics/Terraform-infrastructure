# Main Infrastructure Resources for Lineup-Optim
# ECR Repositories, IAM, Lambda Functions, CloudWatch

# ─── ECR Repositories ───────────────────────────────────────────────

resource "aws_ecr_repository" "web_app" {
  name                 = var.web_app_ecr_name
  image_tag_mutability = "MUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project     = var.project_name
    Component   = var.component_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_ecr_repository" "web_server" {
  name                 = var.web_server_ecr_name
  image_tag_mutability = "MUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project     = var.project_name
    Component   = var.component_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ─── IAM Roles and Policies ─────────────────────────────────────────

resource "aws_iam_role" "lambda_execution" {
  name = "lineup-optim-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
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

# Attach AWS managed policy for VPC networking
resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Inline policy for CloudWatch log creation
resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "lineup-optim-cloudwatch-logs"
  role = aws_iam_role.lambda_execution.id

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
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/lineup-optim-*:*"
      }
    ]
  })
}

# Inline policy for SSM parameter read access scoped to /slugger/lineup-optim/*
resource "aws_iam_role_policy" "ssm_read" {
  name = "lineup-optim-ssm-read"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/slugger/lineup-optim/*"
      }
    ]
  })
}

# ─── Lambda Functions ────────────────────────────────────────────────

resource "aws_lambda_function" "web_app" {
  function_name = "lineup-optim-web-app"
  role          = aws_iam_role.lambda_execution.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.web_app.repository_url}:latest"
  memory_size   = var.web_app_memory
  timeout       = var.web_app_timeout
  architectures = ["arm64"]

  vpc_config {
    subnet_ids         = data.aws_subnets.private.ids
    security_group_ids = [data.aws_security_group.ecs_tasks.id]
  }

  environment {
    variables = {
      DATABASE_URL                  = var.database_url
      NEXT_PUBLIC_SUPABASE_URL      = var.supabase_url
      NEXT_PUBLIC_SUPABASE_ANON_KEY = var.supabase_anon_key
      NEXT_PUBLIC_BACKEND_URL       = "/widgets/lineup/api/optimizer"
      BASE_PATH                     = "/widgets/lineup"
    }
  }

  tags = {
    Project     = var.project_name
    Component   = var.component_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_lambda_function" "web_server" {
  function_name = "lineup-optim-web-server"
  role          = aws_iam_role.lambda_execution.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.web_server.repository_url}:latest"
  memory_size   = var.web_server_memory
  timeout       = var.web_server_timeout
  architectures = ["arm64"]

  vpc_config {
    subnet_ids         = data.aws_subnets.private.ids
    security_group_ids = [data.aws_security_group.ecs_tasks.id]
  }

  environment {
    variables = {
      OPENAI_API_KEY = var.openai_api_key
    }
  }

  tags = {
    Project     = var.project_name
    Component   = var.component_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ─── CloudWatch Log Groups ──────────────────────────────────────────

resource "aws_cloudwatch_log_group" "web_app" {
  name              = "/aws/lambda/lineup-optim-web-app"
  retention_in_days = 14

  tags = {
    Project     = var.project_name
    Component   = var.component_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_log_group" "web_server" {
  name              = "/aws/lambda/lineup-optim-web-server"
  retention_in_days = 14

  tags = {
    Project     = var.project_name
    Component   = var.component_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ─── ALB Target Groups ──────────────────────────────────────────────

resource "aws_lb_target_group" "web_server" {
  name        = "tg-lineup-optim-server"
  target_type = "lambda"

  tags = {
    Project     = var.project_name
    Component   = var.component_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_lb_target_group" "web_app" {
  name        = "tg-lineup-optim-app"
  target_type = "lambda"

  tags = {
    Project     = var.project_name
    Component   = var.component_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ─── Lambda Permissions for ALB ──────────────────────────────────────

resource "aws_lambda_permission" "alb_web_server" {
  statement_id  = "AllowALBInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.web_server.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.web_server.arn
}

resource "aws_lambda_permission" "alb_web_app" {
  statement_id  = "AllowALBInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.web_app.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.web_app.arn
}

# ─── Target Group Attachments ────────────────────────────────────────

resource "aws_lb_target_group_attachment" "web_server" {
  target_group_arn = aws_lb_target_group.web_server.arn
  target_id        = aws_lambda_function.web_server.arn
  depends_on       = [aws_lambda_permission.alb_web_server]
}

resource "aws_lb_target_group_attachment" "web_app" {
  target_group_arn = aws_lb_target_group.web_app.arn
  target_id        = aws_lambda_function.web_app.arn
  depends_on       = [aws_lambda_permission.alb_web_app]
}

# ─── ALB Listener Rules ─────────────────────────────────────────────

# Web_Server HTTPS (priority 290 — more specific path matched first)
resource "aws_lb_listener_rule" "web_server_https" {
  listener_arn = data.aws_lb_listener.https.arn
  priority     = var.web_server_alb_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_server.arn
  }

  condition {
    path_pattern {
      values = ["/widgets/lineup/api/optimizer/*"]
    }
  }

  tags = {
    Project     = var.project_name
    Component   = var.component_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Web_Server HTTP (priority 290)
resource "aws_lb_listener_rule" "web_server_http" {
  listener_arn = data.aws_lb_listener.http.arn
  priority     = var.web_server_alb_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_server.arn
  }

  condition {
    path_pattern {
      values = ["/widgets/lineup/api/optimizer/*"]
    }
  }

  tags = {
    Project     = var.project_name
    Component   = var.component_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Web_App HTTPS (priority 300 — catch-all for /widgets/lineup/*)
resource "aws_lb_listener_rule" "web_app_https" {
  listener_arn = data.aws_lb_listener.https.arn
  priority     = var.web_app_alb_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_app.arn
  }

  condition {
    path_pattern {
      values = ["/widgets/lineup/*"]
    }
  }

  tags = {
    Project     = var.project_name
    Component   = var.component_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Web_App HTTP (priority 300)
resource "aws_lb_listener_rule" "web_app_http" {
  listener_arn = data.aws_lb_listener.http.arn
  priority     = var.web_app_alb_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_app.arn
  }

  condition {
    path_pattern {
      values = ["/widgets/lineup/*"]
    }
  }

  tags = {
    Project     = var.project_name
    Component   = var.component_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
