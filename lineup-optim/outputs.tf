# Output Values for Lineup-Optim Lambda Deployment
# Component: lineup-optim (Next.js Web_App + Python FastAPI Web_Server)

# Lambda Function ARNs

output "web_app_lambda_arn" {
  description = "ARN of the Web_App Lambda function"
  value       = aws_lambda_function.web_app.arn
}

output "web_server_lambda_arn" {
  description = "ARN of the Web_Server Lambda function"
  value       = aws_lambda_function.web_server.arn
}

# ECR Repository URLs

output "web_app_ecr_url" {
  description = "URL of the Web_App ECR repository"
  value       = aws_ecr_repository.web_app.repository_url
}

output "web_server_ecr_url" {
  description = "URL of the Web_Server ECR repository"
  value       = aws_ecr_repository.web_server.repository_url
}

# Target Group ARNs

output "web_app_target_group_arn" {
  description = "ARN of the Web_App ALB target group"
  value       = aws_lb_target_group.web_app.arn
}

output "web_server_target_group_arn" {
  description = "ARN of the Web_Server ALB target group"
  value       = aws_lb_target_group.web_server.arn
}

# CloudWatch Log Group Names

output "web_app_log_group_name" {
  description = "CloudWatch log group name for the Web_App"
  value       = aws_cloudwatch_log_group.web_app.name
}

output "web_server_log_group_name" {
  description = "CloudWatch log group name for the Web_Server"
  value       = aws_cloudwatch_log_group.web_server.name
}
