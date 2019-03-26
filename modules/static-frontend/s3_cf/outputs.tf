output "s3_id" {
  value = "${module.bucket-website.s3_id}"
}
output "s3_arn" {
  value = "${module.bucket-website.s3_arn}"
}
output "cf_domain_name" {
  value = "${aws_cloudfront_distribution.www_distribution.domain_name}"
}

output "cf_id" {
  value = "${aws_cloudfront_distribution.www_distribution.id}"
}

output "cf_hosted_zone_id" {
  value = "${aws_cloudfront_distribution.www_distribution.hosted_zone_id}"
}
