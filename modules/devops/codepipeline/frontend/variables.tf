variable "aws_region" {
  default = "eu-central-1"
}

variable "environment" {}

variable "project" {}

variable "build_environment" {}

variable "repo_name" {}

variable "s3_bucket" {}

variable "cloudfront" {}

variable "manual_approve" {
  default = false
}

variable "branch" {
  default = ""
}
