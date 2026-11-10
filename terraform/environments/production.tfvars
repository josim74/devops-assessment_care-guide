aws_region            = "us-east-1"
environment           = "production"
instance_type         = "t3.micro"
app_port              = 8080
container_image       = "ghcr.io/josim/care-guide-service:1.0.0"
log_retention_days    = 30
allowed_ingress_cidrs = ["0.0.0.0/0"]
