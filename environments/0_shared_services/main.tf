provider "aws" {
  region = "${var.aws_region}"
  profile = "${var.profile}"
}

module "prod_tf_backend" {
  source = "../../modules/devops/tf_backend"

  environment = "infra"
  project     = "${var.project}"
}
