variable "region" {
  default = "us-east-1"
}

variable "environment" {
  default = "dev"
}

variable "project" {
  default = "gnosis"
}

variable "www_domain_name" {
  description = "Full Domain Name"
}

variable "cert_arn" {
  description = "Certificate ARN for CloudFront"
}

variable "lambda_cf_headers_qualified_arn" {
  
}

