##################################################################################################
############################################# Config #############################################
##################################################################################################

locals {
  prefix = "${var.environment}-${var.project}"

  branch_temp = "release/${var.environment}"
  branch = "${var.branch != "" ? var.branch : local.branch_temp}"

  common_tags = {
    Project     = "${var.project}"
    Environment = "${var.environment}"
    Managed     = "Terraform"
  }
}


##################################################################################################
########################################### DevOps IAM ###########################################
##################################################################################################

######################################## CodePipeline IAM ########################################

data "template_file" "codepipeline_role" {
  template = "${file("${path.module}/policies/codepipeline_role.json")}"
}

resource "aws_iam_role" "codepipeline" {
  name               = "${local.prefix}-codepipeline-frontend-role"
  assume_role_policy = "${data.template_file.codepipeline_role.rendered}"
}

data "template_file" "codepipeline_policy" {
  template = "${file("${path.module}/policies/codepipeline_policy.json")}"

  vars {
    kms_arn = "${aws_kms_key.artifact_encryption_key.arn}"
  }
}

resource "aws_iam_role_policy" "codepipeline" {
  name   = "${local.prefix}-codepipeline-frontend-policy"
  role   = "${aws_iam_role.codepipeline.id}"
  policy = "${data.template_file.codepipeline_policy.rendered}"
}

######################################## CodeBuild IAM ########################################
data "template_file" "codebuild_role" {
  template = "${file("${path.module}/policies/codebuild_role.json")}"
}

resource "aws_iam_role" "codebuild" {
  name               = "${local.prefix}-codebuild-frontend-role"
  assume_role_policy = "${data.template_file.codebuild_role.rendered}"
}

data "template_file" "codebuild_policy" {
  template = "${file("${path.module}/policies/codebuild_policy.json")}"

  vars {
    kms_arn = "${aws_kms_key.artifact_encryption_key.arn}"
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "${local.prefix}-codebuild-frontend-policy"
  role   = "${aws_iam_role.codebuild.id}"
  policy = "${data.template_file.codebuild_policy.rendered}"
}

##################################################################################################
######################################### Frontend CI/CD #########################################
############################ Note to Falko: Here Comes the Nasty Part ############################
###################### This needs to be restructured into multiple modules #######################
##################################################################################################

########################################## CodeBuild ##########################################

data "template_file" "buildspec_frontend_build" {
  template = "${file("${path.module}/buildspecs/build.yml")}"

  vars {
    s3_bucket         = "${var.s3_bucket}"
    cloudfront        = "${var.cloudfront}"
    build_environment = "${var.build_environment == "" ? var.environment : var.build_environment}"
  }
}

resource "aws_codebuild_project" "build_frontend" {
  name          = "${local.prefix}-build_frontend"
  service_role  = "${aws_iam_role.codebuild.arn}"
  build_timeout = "10"                            # minutes

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_MEDIUM"
    image        = "aws/codebuild/nodejs:8.11.0"
    type         = "LINUX_CONTAINER"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "${data.template_file.buildspec_frontend_build.rendered}"
  }
}

####################################### CodePipeline: Frontend DEV #######################################

resource "aws_sns_topic" "pipeline_approvals" {
  name = "${local.prefix}-pipeline_approvals_frontend"
}

# Encryption key for build artifacts
resource "aws_kms_key" "artifact_encryption_key" {
  description             = "${local.prefix}artifact-encryption-key"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket" "frontend_artifact_store" {
  bucket        = "${local.prefix}-frontend-pipeline-artifact-store"
  force_destroy = true
  acl           = "private"
}

resource "aws_codepipeline" "frontend" {
  count    = "${1-var.manual_approve}"
  name     = "${local.prefix}-frontend-pipeline"
  role_arn = "${aws_iam_role.codepipeline.arn}"

  artifact_store = {
    location = "${aws_s3_bucket.frontend_artifact_store.bucket}"
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Checkout_Repo"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      output_artifacts = ["source"]
      version          = "1"

      configuration {
        RepositoryName = "${var.repo_name}"
        BranchName     = "${local.branch}"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build_And_Upload"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source"]
      output_artifacts = ["dist"]
      version          = "1"

      configuration {
        ProjectName = "${aws_codebuild_project.build_frontend.name}"
      }
    }
  }
}


resource "aws_codepipeline" "frontend_manual_approve" {
  count    = "${var.manual_approve}"
  name     = "${local.prefix}-frontend-pipeline"
  role_arn = "${aws_iam_role.codepipeline.arn}"

  artifact_store = {
    location = "${aws_s3_bucket.frontend_artifact_store.bucket}"
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Checkout_Repo"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      output_artifacts = ["source"]
      version          = "1"

      configuration {
        RepositoryName = "${var.repo_name}"
        BranchName     = "${local.branch}"
      }
    }
  }

  stage {
  name = "Approve"

  action {
    name     = "Approval"
    category = "Approval"
    owner    = "AWS"
    provider = "Manual"
    version  = "1"

    configuration {
      NotificationArn = "${aws_sns_topic.pipeline_approvals.arn}"
      CustomData = "Approve that. Please."
      ExternalEntityLink = "https://${var.aws_region}.console.aws.amazon.com/codesuite/codepipeline/pipelines/${local.prefix}-frontend-pipeline/view?region=${var.aws_region}"
    }
  }
}

  stage {
    name = "Build"

    action {
      name             = "Build_And_Upload"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source"]
      output_artifacts = ["dist"]
      version          = "1"

      configuration {
        ProjectName = "${aws_codebuild_project.build_frontend.name}"
      }
    }
  }
}

