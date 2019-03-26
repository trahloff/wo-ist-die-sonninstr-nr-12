resource "aws_resourcegroups_group" "_" {
  name        = "${var.project}-${var.environment}"
  description = "All ressources belonging to ${var.project} ${var.environment}"

  resource_query {
    query = <<JSON
{
  "ResourceTypeFilters": [
    "AWS::AllSupported"
  ],
  "TagFilters": [
    {
      "Key": "Project",
      "Values": ["${var.project}"]
    },
    {
      "Key": "Environment",
      "Values": ["${var.environment}"]
    },
    {
      "Key": "Managed",
      "Values": ["Terraform"]
    }
  ]
}
JSON
  }
}