# Data Sources for Existing Infrastructure
# References existing SLUGGER infrastructure without modifying it.
# All existing resources are referenced via data blocks, never resource blocks.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_vpc" "main" {
  id = "vpc-030c8d613fc104199"
}

data "aws_lb" "slugger" {
  arn = "arn:aws:elasticloadbalancing:us-east-2:746669223415:loadbalancer/app/slugger-alb/09d85a00869374c7"
}

data "aws_lb_listener" "https" {
  load_balancer_arn = data.aws_lb.slugger.arn
  port              = 443
}

data "aws_lb_listener" "http" {
  load_balancer_arn = data.aws_lb.slugger.arn
  port              = 80
}

data "aws_security_group" "alb" {
  id = "sg-0c35c445084f80855"
}

# Reuse the ECS tasks security group for Lambda VPC networking (same pattern as other widgets)
data "aws_security_group" "ecs_tasks" {
  id = "sg-0c985525970ae7372"
}

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

data "aws_rds_cluster" "aurora" {
  cluster_identifier = "alpb-1"
}
