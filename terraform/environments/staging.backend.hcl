# Replace bucket / dynamodb_table with your pre-created state resources
bucket         = "care-guide-tfstate-bucket"
key            = "staging/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "care-guide-tf-locks"
encrypt        = true
