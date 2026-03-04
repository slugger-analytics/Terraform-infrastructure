# SSM Parameter Store Definitions for Lineup-Optim
# Stores application configuration under /slugger/lineup-optim/*
# SecureString for secrets, String for non-sensitive values

# ─── SecureString Parameters (Secrets) ───────────────────────────────

resource "aws_ssm_parameter" "database_url" {
  name  = "/slugger/lineup-optim/database-url"
  type  = "SecureString"
  value = var.database_url

  tags = {
    Project     = var.project_name
    Component   = var.component_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_ssm_parameter" "openai_api_key" {
  name  = "/slugger/lineup-optim/openai-api-key"
  type  = "SecureString"
  value = var.openai_api_key

  tags = {
    Project     = var.project_name
    Component   = var.component_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_ssm_parameter" "sports_radar_api_key" {
  name  = "/slugger/lineup-optim/sports-radar-api-key"
  type  = "SecureString"
  value = var.sports_radar_api_key

  tags = {
    Project     = var.project_name
    Component   = var.component_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_ssm_parameter" "pointstreak_api_key" {
  name  = "/slugger/lineup-optim/pointstreak-api-key"
  type  = "SecureString"
  value = var.pointstreak_api_key

  tags = {
    Project     = var.project_name
    Component   = var.component_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ─── String Parameters (Non-Sensitive) ───────────────────────────────

resource "aws_ssm_parameter" "supabase_url" {
  name  = "/slugger/lineup-optim/supabase-url"
  type  = "String"
  value = var.supabase_url

  tags = {
    Project     = var.project_name
    Component   = var.component_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_ssm_parameter" "supabase_anon_key" {
  name  = "/slugger/lineup-optim/supabase-anon-key"
  type  = "String"
  value = var.supabase_anon_key

  tags = {
    Project     = var.project_name
    Component   = var.component_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_ssm_parameter" "backend_url" {
  name  = "/slugger/lineup-optim/backend-url"
  type  = "String"
  value = "/widgets/lineup/api/optimizer"

  tags = {
    Project     = var.project_name
    Component   = var.component_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
