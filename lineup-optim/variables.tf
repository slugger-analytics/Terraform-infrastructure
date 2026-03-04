# Input Variables for Lineup-Optim Lambda Deployment
# Component: lineup-optim (Next.js Web_App + Python FastAPI Web_Server)

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Name of the parent project"
  type        = string
  default     = "slugger"
}

variable "component_name" {
  description = "Name identifier for this component"
  type        = string
  default     = "lineup-optim"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

# Lambda Memory and Timeout Settings

variable "web_app_memory" {
  description = "Lambda memory size in MB for the Web_App (Next.js)"
  type        = number
  default     = 512
}

variable "web_app_timeout" {
  description = "Lambda timeout in seconds for the Web_App"
  type        = number
  default     = 30
}

variable "web_server_memory" {
  description = "Lambda memory size in MB for the Web_Server (FastAPI)"
  type        = number
  default     = 1024
}

variable "web_server_timeout" {
  description = "Lambda timeout in seconds for the Web_Server"
  type        = number
  default     = 30
}

# ECR Repository Names

variable "web_app_ecr_name" {
  description = "ECR repository name for the Web_App container image"
  type        = string
  default     = "lineup-optim-web-app"
}

variable "web_server_ecr_name" {
  description = "ECR repository name for the Web_Server container image"
  type        = string
  default     = "lineup-optim-web-server"
}

# ALB Listener Rule Priorities

variable "web_server_alb_priority" {
  description = "ALB listener rule priority for Web_Server (more specific path, lower number = higher precedence)"
  type        = number
  default     = 290
}

variable "web_app_alb_priority" {
  description = "ALB listener rule priority for Web_App (catch-all /widgets/lineup/*)"
  type        = number
  default     = 300
}

# SSM Secret Values (provided at apply time)

variable "database_url" {
  description = "PostgreSQL connection string for Aurora cluster"
  type        = string
  sensitive   = true
}

variable "supabase_url" {
  description = "Supabase project URL for authentication"
  type        = string
}

variable "supabase_anon_key" {
  description = "Supabase anonymous key for client-side auth"
  type        = string
}

variable "openai_api_key" {
  description = "OpenAI API key for RAG chatbot"
  type        = string
  sensitive   = true
}

variable "sports_radar_api_key" {
  description = "Sports Radar API key for game data"
  type        = string
  sensitive   = true
}

variable "pointstreak_api_key" {
  description = "Pointstreak API key for league data"
  type        = string
  sensitive   = true
}
