locals {
  prefix = "${var.environment}-${var.project}"

  common_tags = {
    Project     = "${var.project}"
    Environment = "${var.environment}"
    Managed     = "Terraform"
  }
}

resource "aws_acm_certificate" "cert" {
  domain_name               = "${var.www_domain}"
  validation_method         = "DNS"
  subject_alternative_names = ["*.${var.www_domain}"]

  tags = "${merge(
    local.common_tags,
    map(
      "Name", "${local.prefix}-wildcard_cert"
    )
  )}"
}

resource "aws_route53_record" "cert_validation" {
  name    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_type}"
  zone_id = "${var.r53_zone_id}"
  records = ["${aws_acm_certificate.cert.domain_validation_options.0.resource_record_value}"]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = "${aws_acm_certificate.cert.arn}"
  validation_record_fqdns = ["${aws_route53_record.cert_validation.fqdn}"]
}
