variable "environment" {
  description = "The deployment environment"
}

variable "lambda_arn" {
  description = "The arn of the lambda"
}

variable "fields" {
  description = <<EOF
  A list of maps,
    {
      value: value corresponding to the gql fields from which to resolve to the lambda
      type: E.g. Mutation, or Query, the gql type
EOF

  type = "list"
}

locals {
  # datasource_name = "${md5(format("%s%s", var.lambda_arn, jsonencode(var.fields)))}"
  datasource_name = "ds${substr(md5(jsonencode(var.fields)), 0, 30)}"
}

resource "aws_iam_role" "role" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "sts:AssumeRole"
      ],
      "Principal": {
        "Service": [
          "appsync.amazonaws.com"
        ]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "policy" {
  role = "${aws_iam_role.role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "lambda:invokeFunction"
      ],
      "Effect": "Allow",
      "Resource": [
        "${var.lambda_arn}"
      ]
    }
  ]
}
EOF
}

data "terraform_remote_state" "appsync_api" {
  backend = "s3"

  config {
    bucket = "${var.remote_state_bucket}"
    key    = "${var.appsync_api_remote_state_path}/${var.environment}/terraform.tfstate"
    region = "eu-central-1"
  }
}

resource "aws_appsync_datasource" "appsync_lambda" {
  api_id = "${data.terraform_remote_state.appsync_api.api_id}"
  name   = "${local.datasource_name}"
  type   = "AWS_LAMBDA"

  lambda_config {
    function_arn = "${var.lambda_arn}"
  }

  service_role_arn = "${aws_iam_role.role.arn}"
}

data "external" "resolver_stack" {
  program = [
    "node",
    "${path.module}/resolver.js",
    "--ApiId=${data.terraform_remote_state.appsync_api.api_id}",
    "--fields=${jsonencode(var.fields)}",
    "--DataSourceName=${local.datasource_name}",
  ]
}

resource "aws_cloudformation_stack" "resolver" {
  depends_on       = ["aws_appsync_datasource.appsync_lambda"]
  name             = "${data.external.resolver_stack.result.stack_name}"
  template_body    = "${data.external.resolver_stack.result.cloud_formation_stack}"
  on_failure       = "DELETE"
}
