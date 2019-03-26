variable "environment" {}

variable "rendered_function_code" {}

variable "function_name" {}

variable "runtime" {}

variable "memory_size" {}

variable "handler_function_name" {
  default = "handler"
}

variable "timeout" {
  default = 3
}

variable "project" {
  description = "Name of the project that is deployed"
}
