output "s3_bucket" {
  value = "${aws_s3_bucket.backend_bucket.bucket}"
}

output "dynamo_table" {
  value = "${aws_dynamodb_table.backend_lock.name}"
}
