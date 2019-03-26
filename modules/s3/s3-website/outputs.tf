output "s3_arn" {
  value = "${aws_s3_bucket.this.arn}"
}

output "s3_id" {
  value = "${aws_s3_bucket.this.id}"
}

output "s3_bucket" {
  value = "${aws_s3_bucket.this.bucket}"
}

output "s3_bucket_domain_name" {
  value = "${aws_s3_bucket.this.bucket_domain_name}"
}

output "s3_region" {
  value = "${aws_s3_bucket.this.region}"
}

output "s3_versioning" {
  value = "${aws_s3_bucket.this.versioning}"
}

output "s3_tags" {
  value = "${aws_s3_bucket.this.tags}"
}

output "s3_policy" {
  value = "${aws_s3_bucket.this.policy}"
}

output "s3_website_endpoint" {
  value = "${aws_s3_bucket.this.website_endpoint}"
}

output "s3_website_domain" {
  value = "${aws_s3_bucket.this.website_domain}"
}
