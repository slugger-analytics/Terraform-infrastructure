# Terraform and AWS Provider Configuration
# Widget: ClubhouseWidget

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "slugger"
      Component   = "widget-${var.widget_name}"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
