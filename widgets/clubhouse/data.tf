# Data Sources for Existing Infrastructure
# References existing SLUGGER infrastructure without modifying it

# Current AWS Account
data "aws_caller_identity" "current" {}

# Current AWS Region
data "aws_region" "current" {}

# Existing VPC
data "aws_vpc" "main" {
  id = "vpc-030c8d613fc104199"
}

# Existing ALB
data "aws_lb" "slugger" {
  arn = "arn:aws:elasticloadbalancing:us-east-2:746669223415:loadbalancer/app/slugger-alb/09d85a00869374c7"
}

# HTTPS Listener (port 443)
data "aws_lb_listener" "https" {
  load_balancer_arn = data.aws_lb.slugger.arn
  port              = 443
}

# HTTP Listener (port 80)
data "aws_lb_listener" "http" {
  load_balancer_arn = data.aws_lb.slugger.arn
  port              = 80
}

# ALB Security Group
data "aws_security_group" "alb" {
  id = "sg-0c35c445084f80855"
}

# Existing ECS Security Group (used for Lambda VPC access)
data "aws_security_group" "ecs_tasks" {
  id = "sg-0c985525970ae7372"
}

# Private Subnets
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  filter {
    name   = "tag:Type"
    values = ["private"]
  }
}
