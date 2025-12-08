# Input Variables for Batter Widget Lambda Deployment

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-2"
}

variable "widget_name" {
  description = "Name identifier for the widget"
  type        = string
  default     = "flashcard"
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

variable "slugger_api_url" {
  description = "SLUGGER API Gateway URL"
  type        = string
  default     = "https://1ywv9dczq5.execute-api.us-east-2.amazonaws.com/ALPBAPI"
}
