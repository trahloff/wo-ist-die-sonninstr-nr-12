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
  name               = "${local.prefix}-codepipeline-backend-role"
  assume_role_policy = "${data.template_file.codepipeline_role.rendered}"
}

data "template_file" "codepipeline_policy" {
  template = "${file("${path.module}/policies/codepipeline_policy.json")}"

  vars {
    kms_arn = "${aws_kms_key.artifact_encryption_key.arn}"
  }
}

resource "aws_iam_role_policy" "codepipeline" {
  name   = "${local.prefix}-codepipeline-backend-policy"
  role   = "${aws_iam_role.codepipeline.id}"
  policy = "${data.template_file.codepipeline_policy.rendered}"
}

######################################## CodeBuild IAM ########################################
data "template_file" "codebuild_role" {
  template = "${file("${path.module}/policies/codebuild_role.json")}"
}

resource "aws_iam_role" "codebuild" {
  name               = "${local.prefix}-codebuild-backend-role"
  assume_role_policy = "${data.template_file.codebuild_role.rendered}"
}

data "template_file" "codebuild_policy" {
  template = "${file("${path.module}/policies/codebuild_policy.json")}"

  vars {
    kms_arn = "${aws_kms_key.artifact_encryption_key.arn}"
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "${local.prefix}-codebuild-backend-policy"
  role   = "${aws_iam_role.codebuild.id}"
  policy = "${data.template_file.codebuild_policy.rendered}"
}

##################################################################################################
######################################### Backend CI/CD #########################################
############################ Note to Falko: Here Comes the Nasty Part ############################
###################### This needs to be restructured into multiple modules #######################
##################################################################################################

########################################## CodeBuild ##########################################

data "template_file" "buildspec_backend_build" {
  template = "${file("${path.module}/buildspecs/build.yml")}"

  vars {
    docker_repository_url = "${var.docker_repository_url}"
    environment           = "${var.environment}"
    project               = "${var.project}"
  }
}

resource "aws_codebuild_project" "build_backend" {
  name          = "${local.prefix}-build_backend"
  service_role  = "${aws_iam_role.codebuild.arn}"
  build_timeout = "10"                            # minutes

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/docker:18.09.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "${data.template_file.buildspec_backend_build.rendered}"
  }
}

####################################### CodePipeline: backend DEV #######################################

resource "aws_sns_topic" "pipeline_approvals" {
  name = "${local.prefix}-pipeline_approvals_backend"
}

# Encryption key for build artifacts
resource "aws_kms_key" "artifact_encryption_key" {
  description             = "${local.prefix}artifact-encryption-key"
  deletion_window_in_days = 10
}

resource "aws_kms_alias" "artifact_encryption_key_alias" {
  name          = "alias/${var.project}/${var.environment}/backend-cicd"
  target_key_id = "${aws_kms_key.artifact_encryption_key.key_id}"
}
resource "aws_s3_bucket" "backend_artifact_store" {
  bucket        = "${local.prefix}-backend-pipeline-artifact-store"
  force_destroy = true
  acl           = "private"
}

resource "aws_codepipeline" "backend" {
  count    = "${1-var.manual_approve}"
  name     = "${local.prefix}-backend-pipeline"
  role_arn = "${aws_iam_role.codepipeline.arn}"

  artifact_store = {
    location = "${aws_s3_bucket.backend_artifact_store.bucket}"
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
      name             = "Build_And_Push_Docker"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source"]
      output_artifacts = ["imagedefinitions"]
      version          = "1"

      configuration {
        ProjectName = "${aws_codebuild_project.build_backend.name}"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Update_ECS_Cluster"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["imagedefinitions"]
      version         = "1"

      configuration {
        ClusterName = "${var.ecs_cluster_name}"
        ServiceName = "${var.ecs_service_name}"
        FileName    = "imagedefinitions.json"
      }
    }
  }
}

resource "aws_codepipeline" "backend_manual_approve" {
  count    = "${var.manual_approve}"
  name     = "${local.prefix}-backend-pipeline"
  role_arn = "${aws_iam_role.codepipeline.arn}"

  artifact_store = {
    location = "${aws_s3_bucket.backend_artifact_store.bucket}"
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
      name             = "Build_And_Push_Docker"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source"]
      output_artifacts = ["imagedefinitions"]
      version          = "1"

      configuration {
        ProjectName = "${aws_codebuild_project.build_backend.name}"
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
        NotificationArn    = "${aws_sns_topic.pipeline_approvals.arn}"
        CustomData         = "Approve that. Please. Or not. Man. Whatever you want."
        ExternalEntityLink = "https://${var.aws_region}.console.aws.amazon.com/codesuite/codepipeline/pipelines/${local.prefix}-backend-pipeline/view?region=${var.aws_region}"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Update_ECS_Cluster"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["imagedefinitions"]
      version         = "1"

      configuration {
        ClusterName = "${var.ecs_cluster_name}"
        ServiceName = "${var.ecs_service_name}"
        FileName    = "imagedefinitions.json"
      }
    }
  }
}
