# Terraform and AWS Provider Configuration
# Component: lineup-optim (Next.js Web_App + Python FastAPI Web_Server)

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
      Component   = "lineup-optim"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
