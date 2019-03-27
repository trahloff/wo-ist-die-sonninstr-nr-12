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

##################################################################################################
####################################### Root (wo-ist-...) ########################################
##################################################################################################

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

module "www_frontend" {
  source          = "../../modules/static-frontend/s3_cf"
  region          = "${var.aws_region}"
  environment     = "${var.environment}"
  project         = "${var.project}"
  www_domain_name = "${var.root_domain_name}"

  cert_arn = "${module.cert_cf.cert_arn}"
}


resource "aws_s3_bucket_object" "index" {
  bucket = "${module.www_frontend.s3_id}"
  key    = "index.html"
  source = "statics/index.html"
  etag   = "${md5("statics/index.html")}"
}

resource "aws_s3_bucket_object" "map" {
  bucket = "${module.www_frontend.s3_id}"
  key    = "map.png"
  source = "statics/map.png"
  etag   = "${md5("statics/map.png")}"
}

resource "aws_s3_bucket_object" "css" {
  bucket = "${module.www_frontend.s3_id}"
  key    = "styles.css"
  source = "statics/styles.css"
  etag   = "${md5("statics/styles.css")}"
}

resource "aws_route53_record" "www_plain" {
  zone_id = "${data.aws_route53_zone.root.zone_id}"
  name    = "${var.root_domain_name}"
  type    = "A"

  alias = {
    name                   = "${module.www_frontend.cf_domain_name}"
    zone_id                = "${module.www_frontend.cf_hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www_with_prefix" {
  zone_id = "${data.aws_route53_zone.root.zone_id}"
  name    = "www.${var.root_domain_name}"
  type    = "A"

  alias = {
    name                   = "${module.www_frontend.cf_domain_name}"
    zone_id                = "${module.www_frontend.cf_hosted_zone_id}"
    evaluate_target_health = false
  }
}

##################################################################################################
####################################### alternative-routes #######################################
##################################################################################################

# module "cert_cf" {
#   source = "../../modules/acm"

#   environment = "${var.environment}"
#   project     = "${var.project}"
#   www_domain  = "${var.root_domain_name}"
#   r53_zone_id = "${data.aws_route53_zone.root.zone_id}"

#   providers = {
#     aws = "aws.us_east" # see above
#   }
# }

# module "asset_cdn" {
#   source    = "../../modules/s3/cdn"
#   namespace = "${var.project}"
#   stage     = "${var.environment}"
#   name      = "${var.project}"

#   acm_certificate_arn      = "${module.cert_cf.cert_arn}"
#   aliases                  = ["www.${var.root_domain_name}", "${var.root_domain_name}"]
#   parent_zone_id           = "${data.aws_route53_zone.root.zone_id}"
#   comment                  = "${local.prefix}"
#   tags                     = "${local.tags}"
#   minimum_protocol_version = "TLSv1.2_2018"
#   use_regional_s3_endpoint = "true"
#   origin_force_destroy     = "true"
# }
