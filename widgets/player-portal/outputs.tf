# Outputs for Player Portal Lambda Deployment

output "web_lambda_arn" {
  description = "ARN of the player-portal-web Lambda"
  value       = aws_lambda_function.web.arn
}

output "api_lambda_arn" {
  description = "ARN of the player-portal-api Lambda"
  value       = aws_lambda_function.api.arn
}

output "sync_lambda_arn" {
  description = "ARN of the player-portal-sync Lambda"
  value       = aws_lambda_function.sync.arn
}

output "web_ecr_url" {
  description = "ECR URL for the web image"
  value       = aws_ecr_repository.web.repository_url
}

output "api_ecr_url" {
  description = "ECR URL for the API/sync image"
  value       = aws_ecr_repository.api.repository_url
}

output "web_target_group_arn" {
  value = aws_lb_target_group.web.arn
}

output "api_target_group_arn" {
  value = aws_lb_target_group.api.arn
}

output "web_log_group" {
  value = aws_cloudwatch_log_group.web.name
}

output "api_log_group" {
  value = aws_cloudwatch_log_group.api.name
}

output "sync_log_group" {
  value = aws_cloudwatch_log_group.sync.name
}

output "widget_url" {
  description = "Public URL for the Player Portal widget"
  value       = "https://alpb-analytics.com/widgets/player-portal"
}

output "nat_elastic_ip" {
  description = "Fixed outbound IP of the NAT Gateway — give this to TBC to whitelist for feed access"
  value       = aws_eip.nat.public_ip
}
