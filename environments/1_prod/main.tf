##################################################################################################
############################################# Config #############################################
##################################################################################################
# Default Provider
provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.profile}"
}

locals {
  prefix = "${var.environment}-${var.project}"

  tags = {
    Project     = "${var.project}"
    Environment = "${var.environment}"
    Managed     = "Terraform"
  }

  main_url = "sonninpark.de"

  alternative_urls = [
    "sonninpark.com",
    "sonninstr.de",
    "sonninstrasse.de",
    "wo-ist-die-sonninstr-nr-12.de",
    "www.sonninpark.de",
    "www.sonninpark.com",
    "www.sonninstr.de",
    "www.sonninstrasse.de",
    "www.wo-ist-die-sonninstr-nr-12.de",
  ]

  urls = [
    "${local.main_url}",
    "${local.alternative_urls}",
  ]
}

##################################################################################################
############################################## CDN ###############################################
##################################################################################################

module "certificate" {
  source = "git::https://github.com/cloudposse/terraform-aws-acm-request-certificate.git?ref=0.1.3"

  domain_name = "${local.main_url}"

  # process_domain_validation_options = "true"
  # validation_method                 = "EMAIL"
  ttl = "300"

  subject_alternative_names = ["${local.alternative_urls}"]

  tags = {
    Name = "sonnin"
  }
}

module "cdn" {
  source                   = "git::https://github.com/cloudposse/terraform-aws-cloudfront-s3-cdn.git?ref=master"
  namespace                = "${var.project}"
  stage                    = "${var.environment}"
  compress                 = true
  use_regional_s3_endpoint = true
  name                     = "${local.prefix}-cdn"
  acm_certificate_arn      = "${module.certificate.arn}"
  aliases                  = "${local.urls}"
  parent_zone_name         = "${local.main_url}"

  tags = "${merge(
    local.tags,
    map(
      "Comment", "${local.prefix}-cdn"
    )
  )}"
}

resource "aws_s3_bucket_object" "index" {
  bucket       = "${module.cdn.s3_bucket}"
  key          = "index.html"
  source       = "statics/index.html"
  content_type = "text/html"
  etag         = "${md5("statics/index.html")}"
}
