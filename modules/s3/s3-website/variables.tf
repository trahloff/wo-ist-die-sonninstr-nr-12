variable "s3_bucket_name" {
  description = "Name of the bucket"
}

variable "s3_bucket_acl" {
  description = "Private or Public"
  default     = "public-read"
}

variable "environment" {
  description = "Environment of the Stack"
  default     = ""
}

variable "project" {
  description = "Specify to which project this resource belongs"
  default     = ""
}

variable "region" {
  description = "Default Region for Gnosis"
  default     = "eu-west-1"
}

variable "versioning_enabled" {
  default = false
}

variable "routing_rules" {
  description = "Routing rules for Website files placed in S3"
  default     = ""
}

variable "s3_index_document" {
  description = "Initial file when accessing the website"
  default     = "index.html"
}

variable "s3_error_document" {
  description = "Document to be redirected to in case of an error"
  default     = "404.html"
}

variable "s3_condition_test" {
  default = "StringLike"
}

variable "s3_condition_type" {
  default     = ""
  description = "Example condition types: 'aws:UserAgent', 'aws:SourceIp'"
}

variable "s3_condition_value" {
  default = []
  type    = "list"
}

variable "s3_force_destroy" {
  description = "Defines whether object within the bucket are automatically deleted on bucket destruction"
  default     = true
}
