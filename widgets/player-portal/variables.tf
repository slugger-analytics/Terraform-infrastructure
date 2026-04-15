# Input Variables for Player Portal Lambda Deployment

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  type    = string
  default = "slugger"
}

variable "component_name" {
  type    = string
  default = "player-portal"
}

variable "environment" {
  type    = string
  default = "production"
}

# ─── Lambda Sizing ────────────────────────────────────────────────────────────

variable "web_memory" {
  description = "Memory in MB for the Next.js web Lambda"
  type        = number
  default     = 512
}

variable "web_timeout" {
  description = "Timeout in seconds for the web Lambda (Next.js cold starts can be slow)"
  type        = number
  default     = 60
}

variable "api_memory" {
  description = "Memory in MB for the Express API Lambda"
  type        = number
  default     = 512
}

variable "api_timeout" {
  description = "Timeout in seconds for the API Lambda"
  type        = number
  default     = 30
}

variable "sync_memory" {
  description = "Memory in MB for the sync Lambda (fetches 3 URLs + DB upserts)"
  type        = number
  default     = 512
}

variable "sync_timeout" {
  description = "Timeout in seconds for the sync Lambda (longer — fetches 3 external URLs)"
  type        = number
  default     = 120
}

# ─── ALB Priorities ───────────────────────────────────────────────────────────
# Existing priorities: 1 (ECS /api/*), 100 (clubhouse), 200 (flashcard),
# 290 (lineup API), 300 (lineup web). Next available slots: 310 and 320.

variable "api_alb_priority" {
  description = "ALB priority for /widgets/player-portal/api/* (evaluated before web)"
  type        = number
  default     = 310
}

variable "web_alb_priority" {
  description = "ALB priority for /widgets/player-portal/* (broader catch-all)"
  type        = number
  default     = 320
}

# ─── Secrets (provided via terraform.tfvars — never commit that file) ─────────

variable "database_url" {
  description = "PostgreSQL connection string for the player_portal database on Aurora alpb-1"
  type        = string
  sensitive   = true
}

variable "tbc_feed_password" {
  description = "Password for The Baseball Cube JHU feed (TBC_FEED_PASSWORD)"
  type        = string
  sensitive   = true
}

variable "sync_internal_key" {
  description = "Shared secret for POST /sync authentication (SYNC_INTERNAL_KEY)"
  type        = string
  sensitive   = true
}
