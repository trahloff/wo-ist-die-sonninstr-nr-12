locals {
  prefix = "${var.environment}-${var.project}"

  common_tags = {
    Project     = "${var.project}"
    Environment = "${var.environment}"
    Managed     = "Terraform"
  }
}

module "bucket-website" {
  source            = "../../s3/s3-website"
  region            = "${var.region}"
  environment       = "${var.environment}"
  project           = "${var.project}"
  s3_bucket_name    = "${var.www_domain_name}"
  s3_index_document = "index.html"

  // error doc has to be index.html to make Angular SPA and URL state possible. 
  // see: https://codecraft.tv/courses/angular/routing/routing-strategies/#_hashlocationstrategy 
  // and https://stackoverflow.com/questions/42018119/angular-2-application-deployed-on-amazon-s3-gives-404-error
  s3_error_document = "index.html"
}

provider "aws" {
  alias  = "cf"
  region = "us-east-1"
}



resource "aws_cloudfront_distribution" "www_distribution" {
  comment = "${local.prefix}-frontend"

  origin {
    // enforce https
    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }

    // bucket webpage endpoint (e.g. "dev-gnosis-testpage.startgnosis.com.s3-website.eu-central-1.amazonaws.com")
    domain_name = "${module.bucket-website.s3_website_endpoint}"

    // This can be any name to identify this origin.
    origin_id = "${var.www_domain_name}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  // All values are defaults from the AWS console.
  default_cache_behavior {
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    // This needs to match the `origin_id` above.
    target_origin_id = "${var.www_domain_name}"
    min_ttl          = 0
    default_ttl      = 86400
    max_ttl          = 31536000

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    lambda_function_association {
      event_type = "viewer-response"
      lambda_arn = "${var.lambda_cf_headers_qualified_arn}"
    }
  }

  // Here we're ensuring we can hit this distribution using the custom domain (e.g. "startgnosis.com")
  // rather than the domain name CloudFront gives us.
  aliases = [
    "${var.www_domain_name}",
    "www.${var.www_domain_name}",
  ]

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  // Here's where our certificate is loaded in!
  viewer_certificate {
    acm_certificate_arn      = "${var.cert_arn}"
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2018"
  }

  tags = "${merge(
    local.common_tags,
    map(
      "Name", "${local.prefix}-frontend"
    )
  )}"
}
