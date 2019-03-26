output "pipeline_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/codesuite/codepipeline/pipelines/${local.prefix}-backend-pipeline/view?region=${var.aws_region}"
}

output "codebuild_build_project_name" {
  value = "${aws_codebuild_project.build_backend.name}"
}

output "codepipeline_arn" {
  value = "${aws_iam_role.codepipeline.arn}"
}
