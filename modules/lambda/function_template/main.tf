locals {
  prefix = "${var.environment}-${var.project}"

  tags = {
    Project     = "${var.project}"
    Environment = "${var.environment}"
    Managed     = "Terraform"
  }
}

data "archive_file" "headers-function" {
  type        = "zip"
  output_path = "${path.module}/.zip/headers_function.zip"

  source {
    filename = "index.js"
    content  = "${var.rendered_function_code}"
  }
}

# IAM
# ---------------------------------------------------------------------

data "aws_iam_policy_document" "lambda-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"

      identifiers = [
        "lambda.amazonaws.com",
        "edgelambda.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "${local.prefix}-${var.function_name}-lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "ses:*"
      ],
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role" "headers-function" {
  name               = "${local.prefix}-${var.function_name}"
  assume_role_policy = "${data.aws_iam_policy_document.lambda-role-policy.json}"
}

resource "aws_iam_role_policy_attachment" "headers-function-role-policy" {
  role       = "${aws_iam_role.headers-function.name}"
  policy_arn = "${aws_iam_policy.lambda_logging.arn}"
}

# Lambda Function
# ---------------------------------------------------------------------

resource "aws_lambda_function" "_" {
  function_name    = "${local.prefix}-${var.function_name}"
  filename         = "${data.archive_file.headers-function.output_path}"
  source_code_hash = "${data.archive_file.headers-function.output_base64sha256}"
  role             = "${aws_iam_role.headers-function.arn}"
  runtime          = "${var.runtime}"
  handler          = "index.${var.handler_function_name}"
  memory_size      = "${var.memory_size}"
  timeout          = "${var.timeout}"
  tags             = "${local.tags}"
  publish          = true
}
