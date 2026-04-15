# SSM Parameter Store for Player Portal
# Stores secrets under /slugger/player-portal/
# Lambda IAM role grants read access to this path only

resource "aws_ssm_parameter" "database_url" {
  name  = "/slugger/player-portal/database-url"
  type  = "SecureString"
  value = var.database_url
  tags  = local.tags
}

resource "aws_ssm_parameter" "tbc_feed_password" {
  name  = "/slugger/player-portal/tbc-feed-password"
  type  = "SecureString"
  value = var.tbc_feed_password
  tags  = local.tags
}

resource "aws_ssm_parameter" "sync_internal_key" {
  name  = "/slugger/player-portal/sync-internal-key"
  type  = "SecureString"
  value = var.sync_internal_key
  tags  = local.tags
}

# Non-sensitive — stored as String so CI can read without KMS permissions
resource "aws_ssm_parameter" "api_url_public" {
  name  = "/slugger/player-portal/api-url-public"
  type  = "String"
  value = "https://alpb-analytics.com/widgets/player-portal/api"
  tags  = local.tags
}
