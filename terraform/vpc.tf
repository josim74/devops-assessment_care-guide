# Query default VPC and public subnets
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security group restricting network exposure to required ports only
resource "aws_security_group" "app_sg" {
  name        = "${var.environment}-care-guide-sg"
  description = "Security group for Care Guide web service on EC2"
  vpc_id      = data.aws_vpc.default.id

  # Ingress for Application Port (8080)
  ingress {
    description = "Allow inbound HTTP to application service"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
  }

  # NOTE: SSH (port 22) is deliberately omitted to prevent public brute force attacks.
  # Shell access and remote commands are managed securely via AWS Systems Manager (SSM) Session Manager.

  # Egress for outbound internet access (ECR/GHCR pulls, package updates, AWS APIs)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-care-guide-sg"
  }
}
