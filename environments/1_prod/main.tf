##################################################################################################
############################################# Config #############################################
##################################################################################################
# Default Provider
provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.profile}"
}

# CloudFront, Lambda@Edge
provider "aws" {
  region  = "us-east-1"
  profile = "${var.profile}"
  alias   = "us_east"
}

locals {
  prefix = "${var.environment}-${var.project}"

  tags = {
    Project     = "${var.project}"
    Environment = "${var.environment}"
    Managed     = "Terraform"
  }
}

data "aws_route53_zone" "root" {
  name         = "${var.root_domain_name}"
  private_zone = false
}

module "cert_cf" {
  source = "../../modules/acm"

  environment = "${var.environment}"
  project     = "${var.project}"
  www_domain  = "${var.root_domain_name}"
  r53_zone_id = "${data.aws_route53_zone.root.zone_id}"

  providers = {
    aws = "aws.us_east" # see above
  }
}

module "asset_cdn" {
  source    = "../../modules/s3/cdn"
  namespace = "${var.project}"
  stage     = "${var.environment}"
  name      = "${var.project}"

  acm_certificate_arn      = "${module.cert_cf.cert_arn}"
  aliases                  = ["www.${var.root_domain_name}", "${var.root_domain_name}"]
  parent_zone_id           = "${data.aws_route53_zone.root.zone_id}"
  comment                  = "${local.prefix}"
  tags                     = "${local.tags}"
  minimum_protocol_version = "TLSv1.2_2018"
  use_regional_s3_endpoint = "true"
  origin_force_destroy     = "true"
  cors_allowed_headers     = ["*"]
  cors_allowed_methods     = ["GET", "HEAD", "PUT"]
  cors_allowed_origins     = ["*"]
  cors_expose_headers      = ["ETag"]
}

resource "aws_s3_bucket_object" "index" {
  bucket = "${module.asset_cdn.s3_bucket}"
  key    = "index.html"
  source = "statics/index.html"
  etag   = "${filemd5("statics/index.html")}"
}

resource "aws_s3_bucket_object" "map" {
  bucket = "${module.asset_cdn.s3_bucket}"
  key    = "map.png"
  source = "statics/map.png"
  etag   = "${filemd5("statics/map.png")}"
}
