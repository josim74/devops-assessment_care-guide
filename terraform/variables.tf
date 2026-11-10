variable "aws_region" {
  description = "AWS region for provisioning resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment (staging or production)"
  type        = string
  default     = "staging"
}

variable "instance_type" {
  description = "EC2 instance type (Free Tier eligible)"
  type        = string
  default     = "t2.micro"
}

variable "app_port" {
  description = "Application listening port"
  type        = number
  default     = 8080
}

variable "container_image" {
  description = "Initial container image to run"
  type        = string
  default     = "ghcr.io/josim/care-guide-service:1.0.0"
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
}

variable "allowed_ingress_cidrs" {
  description = "CIDR blocks allowed to access the application port"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
