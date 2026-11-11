terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50.0"
    }
  }

  # Remote state in S3 with DynamoDB locking. Bucket/table/key are supplied per environment at
  # init time so staging and production never share a state file:
  #   terraform init -reconfigure -backend-config=environments/staging.backend.hcl
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "CareGuideDevOpsAssessment"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
