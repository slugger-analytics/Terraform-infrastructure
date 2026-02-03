# Output Values for ClubhouseWidget Lambda Deployment

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.widget.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.widget.function_name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.widget.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.widget.arn
}

output "target_group_arn" {
  description = "ARN of the Lambda target group"
  value       = aws_lb_target_group.lambda_widget.arn
}

output "alb_path" {
  description = "ALB path pattern for the widget"
  value       = "/widgets/${var.widget_name}/*"
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.lambda_widget.name
}

output "iam_role_arn" {
  description = "ARN of the Lambda IAM role"
  value       = aws_iam_role.lambda_widget.arn
}

output "widget_url" {
  description = "Full URL to access the widget"
  value       = "https://${data.aws_lb.slugger.dns_name}/widgets/${var.widget_name}"
}
