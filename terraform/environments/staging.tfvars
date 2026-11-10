aws_region            = "us-east-1"
environment           = "staging"
instance_type         = "t2.micro"
app_port              = 8080
container_image       = "ghcr.io/josim/care-guide-service:staging-latest"
log_retention_days    = 7
allowed_ingress_cidrs = ["0.0.0.0/0"]
