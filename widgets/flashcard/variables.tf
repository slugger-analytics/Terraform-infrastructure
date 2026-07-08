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
  # 2048 MB matches the live function. The teams/range handler holds tens of thousands of
  # pitch records plus the transformed team payload in the V8 heap; 512 MB OOM'd on 30-day+
  # ranges, and on Lambda memory also scales CPU (~4x here), which speeds the transform.
  default     = 2048
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  # 120 s matches the live function and stays under the slugger-alb 300 s idle timeout.
  # 30 s timed out on multi-week ranges that page through many thousands of pitches.
  default     = 120
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
