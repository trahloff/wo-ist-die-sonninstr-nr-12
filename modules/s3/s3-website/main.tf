locals {
  prefix = "${var.environment}-${var.project}"

  common_tags = {
    Project     = "${var.project}"
    Environment = "${var.environment}"
    Managed     = "Terraform"
  }
}

data "aws_iam_policy_document" "with_condition" {
  statement {
    effect = "Allow"
    sid    = "allowAccessToWebsite"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::${length(var.environment) > 0 ? "${var.environment}-": ""}${length(var.project) > 0 ? "${var.project}-": ""}${var.s3_bucket_name}/*",
    ]

    condition {
      test     = "${var.s3_condition_test}"
      variable = "${var.s3_condition_type}"
      values   = "${var.s3_condition_value}"
    }

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
  }
}

data "aws_iam_policy_document" "without_condition" {
  statement {
    effect = "Allow"
    sid    = "allowAccessToWebsite"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::${length(var.environment) > 0 ? "${var.environment}-": ""}${length(var.project) > 0 ? "${var.project}-": ""}${var.s3_bucket_name}/*",
    ]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket" "this" {
  bucket = "${length(var.environment) > 0 ? "${var.environment}-": ""}${length(var.project) > 0 ? "${var.project}-": ""}${var.s3_bucket_name}"
  acl    = "${var.s3_bucket_acl}"
  region = "${var.region}"
  tags   = "${local.common_tags}"

  versioning {
    enabled = "${var.versioning_enabled}"
  }

  policy = "${ length(var.s3_condition_type) > 0 ? data.aws_iam_policy_document.with_condition.json : data.aws_iam_policy_document.without_condition.json}"

  force_destroy = "${var.s3_force_destroy}"

  website {
    index_document = "${var.s3_index_document}"
    error_document = "${var.s3_error_document}"
    routing_rules  = "${var.routing_rules}"
  }
}
