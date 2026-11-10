terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50.0"
    }
  }

  # Remote backend configuration using S3 for state storage and DynamoDB for state locking
  # NOTE: To initialize, replace bucket and dynamodb_table with your actual state resources:
  #   terraform init -backend-config="bucket=<YOUR_STATE_BUCKET>" -backend-config="dynamodb_table=<YOUR_LOCK_TABLE>"
  backend "s3" {
    bucket         = "care-guide-tfstate-bucket"
    key            = "environments/state.tfstate"
    region         = "us-east-1"
    dynamodb_table = "care-guide-tf-locks"
    encrypt        = true
  }
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
