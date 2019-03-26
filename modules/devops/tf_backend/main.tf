############################################################################
### Creates S3 bucket for state and DynamoDB for locking
### see: https://medium.com/@jessgreb01/how-to-terraform-locking-state-in-s3-2dc9a5665cb6

### After running `$ terraform apply`, upload a .tfstate file and insert the following lines to configure your backend:
# terraform {
#  backend "s3" {
#   encrypt = true
#   bucket = "${var.s3_backend_bucket_name}"
#   dynamodb_table = "${var.dynamo_backend_name}"
#   region = "${var.region}"
#   key = "main.tfstate"
#  }
# }
### Please note that interpolations are not allowed for backend configuration
### and the values for bucket and dynamodb_table therefore have to be replaced with
### the actual bucket name and table name
############################################################################

locals {
  prefix = "${var.environment}-${var.project}"

  common_tags = {
    Project     = "${var.project}"
    Environment = "${var.environment}"
    Managed     = "Terraform"
  }
}

# create a s3 bucket for maintaining state
resource "aws_s3_bucket" "backend_bucket" {
  bucket = "${local.prefix}-tf-state-store"

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = "${local.common_tags}"
}

# create a dynamodb table for locking the state file
resource "aws_dynamodb_table" "backend_lock" {
  name           = "${local.prefix}-tf-lock-store"
  hash_key       = "LockID"
  billing_mode   = "PAY_PER_REQUEST"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = "${local.common_tags}"
}
