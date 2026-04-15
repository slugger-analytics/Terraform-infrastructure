# Main Infrastructure Resources for Player Portal
# ECR Repositories, IAM, Lambda Functions, CloudWatch Logs, ALB Routing

locals {
  tags = {
    Project     = var.project_name
    Component   = var.component_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ─── ECR Repositories ─────────────────────────────────────────────────────────

resource "aws_ecr_repository" "web" {
  name                 = "player-portal-web"
  image_tag_mutability = "MUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.tags
}

resource "aws_ecr_repository" "api" {
  name                 = "player-portal-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.tags
}

# ─── IAM Role ─────────────────────────────────────────────────────────────────

resource "aws_iam_role" "lambda_execution" {
  name = "player-portal-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "player-portal-cloudwatch-logs"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/player-portal-*:*"
    }]
  })
}

resource "aws_iam_role_policy" "ssm_read" {
  name = "player-portal-ssm-read"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["ssm:GetParameter", "ssm:GetParameters"]
      Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/slugger/player-portal/*"
    }]
  })
}

# ─── Lambda Functions ──────────────────────────────────────────────────────────

resource "aws_lambda_function" "web" {
  function_name = "player-portal-web"
  role          = aws_iam_role.lambda_execution.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.web.repository_url}:latest"
  memory_size   = var.web_memory
  timeout       = var.web_timeout
  architectures = ["arm64"]

  vpc_config {
    subnet_ids         = data.aws_subnets.private.ids
    security_group_ids = [data.aws_security_group.ecs_tasks.id]
  }

  environment {
    variables = {
      # Runtime vars used by Next.js server-side rendering.
      # NEXT_PUBLIC_* client-bundle values are baked in at Docker build time.
      NEXT_PUBLIC_BASE_PATH = "/widgets/player-portal"
      NEXT_PUBLIC_API_URL   = "https://alpb-analytics.com/widgets/player-portal/api"
      INTERNAL_API_URL      = "https://alpb-analytics.com/widgets/player-portal/api"
      BASE_PATH             = "/widgets/player-portal"
      SYNC_INTERNAL_KEY     = var.sync_internal_key
    }
  }

  tags = local.tags
}

resource "aws_lambda_function" "api" {
  function_name = "player-portal-api"
  role          = aws_iam_role.lambda_execution.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.api.repository_url}:latest"
  memory_size   = var.api_memory
  timeout       = var.api_timeout
  architectures = ["arm64"]

  vpc_config {
    subnet_ids         = data.aws_subnets.private.ids
    security_group_ids = [data.aws_security_group.ecs_tasks.id]
  }

  environment {
    variables = {
      DATABASE_URL        = var.database_url
      TBC_FEED_PASSWORD   = var.tbc_feed_password
      SYNC_INTERNAL_KEY   = var.sync_internal_key
      PORT                = "8080"
      BASE_PATH           = "/widgets/player-portal"
      CORS_ALLOWED_ORIGIN = "https://alpb-analytics.com"
    }
  }

  tags = local.tags
}

resource "aws_lambda_function" "sync" {
  function_name = "player-portal-sync"
  role          = aws_iam_role.lambda_execution.arn
  package_type  = "Image"

  # Reuses the same ECR image as player-portal-api; CMD is overridden to run
  # the sync pipeline directly instead of the Express HTTP server
  image_uri     = "${aws_ecr_repository.api.repository_url}:latest"
  memory_size   = var.sync_memory
  timeout       = var.sync_timeout
  architectures = ["arm64"]

  image_config {
    command = ["node", "dist/jobs/syncPipeline.js"]
  }

  # In the private NAT subnet so outbound traffic exits through the Elastic IP
  # on the NAT Gateway. This gives a fixed IP that TBC can whitelist.
  vpc_config {
    subnet_ids         = [aws_subnet.sync_private.id]
    security_group_ids = [data.aws_security_group.ecs_tasks.id]
  }

  environment {
    variables = {
      DATABASE_URL      = var.database_url
      TBC_FEED_PASSWORD = var.tbc_feed_password
    }
  }

  tags = local.tags
}

# ─── CloudWatch Log Groups ─────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "web" {
  name              = "/aws/lambda/player-portal-web"
  retention_in_days = 14
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/lambda/player-portal-api"
  retention_in_days = 14
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "sync" {
  name              = "/aws/lambda/player-portal-sync"
  retention_in_days = 14
  tags              = local.tags
}

# ─── ALB Target Groups ─────────────────────────────────────────────────────────

resource "aws_lb_target_group" "api" {
  name        = "tg-player-portal-api"
  target_type = "lambda"
  tags        = local.tags
}

resource "aws_lb_target_group" "web" {
  name        = "tg-player-portal-web"
  target_type = "lambda"
  tags        = local.tags
}

# ─── Lambda Permissions for ALB ────────────────────────────────────────────────

resource "aws_lambda_permission" "alb_api" {
  statement_id  = "AllowALBInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.api.arn
}

resource "aws_lambda_permission" "alb_web" {
  statement_id  = "AllowALBInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.web.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.web.arn
}

# ─── Target Group Attachments ──────────────────────────────────────────────────

resource "aws_lb_target_group_attachment" "api" {
  target_group_arn = aws_lb_target_group.api.arn
  target_id        = aws_lambda_function.api.arn
  depends_on       = [aws_lambda_permission.alb_api]
}

resource "aws_lb_target_group_attachment" "web" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_lambda_function.web.arn
  depends_on       = [aws_lambda_permission.alb_web]
}

# ─── ALB Listener Rules ────────────────────────────────────────────────────────
# API rule has lower priority number (310) so it is evaluated BEFORE the web
# rule (320), ensuring /api/* requests are not swallowed by the web Lambda.

resource "aws_lb_listener_rule" "api_https" {
  listener_arn = data.aws_lb_listener.https.arn
  priority     = var.api_alb_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    path_pattern {
      values = ["/widgets/player-portal/api/*"]
    }
  }

  tags = local.tags
}

resource "aws_lb_listener_rule" "api_http" {
  listener_arn = data.aws_lb_listener.http.arn
  priority     = var.api_alb_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    path_pattern {
      values = ["/widgets/player-portal/api/*"]
    }
  }

  tags = local.tags
}

resource "aws_lb_listener_rule" "web_https" {
  listener_arn = data.aws_lb_listener.https.arn
  priority     = var.web_alb_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  condition {
    path_pattern {
      values = ["/widgets/player-portal", "/widgets/player-portal/*"]
    }
  }

  tags = local.tags
}

resource "aws_lb_listener_rule" "web_http" {
  listener_arn = data.aws_lb_listener.http.arn
  priority     = var.web_alb_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  condition {
    path_pattern {
      values = ["/widgets/player-portal", "/widgets/player-portal/*"]
    }
  }

  tags = local.tags
}
