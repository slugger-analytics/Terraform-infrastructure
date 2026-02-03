# Input Variables for ClubhouseWidget Lambda Deployment

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-2"
}

variable "widget_name" {
  description = "Name identifier for the widget"
  type        = string
  default     = "clubhouse"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 512
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 14
}

variable "cognito_user_pool_id" {
  description = "Cognito User Pool ID for authentication"
  type        = string
  default     = "us-east-2_tG7IQQ6G7"
}

variable "cognito_client_id" {
  description = "Cognito Client ID for authentication"
  type        = string
  default     = "6cttafm6nkv17saapu58a5gdns"
}

variable "db_host" {
  description = "Aurora PostgreSQL cluster endpoint"
  type        = string
  default     = "alpb-1.cluster-cx866cecsebt.us-east-2.rds.amazonaws.com"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "postgres"
}

variable "db_user" {
  description = "Database username"
  type        = string
  default     = "postgres"
}
