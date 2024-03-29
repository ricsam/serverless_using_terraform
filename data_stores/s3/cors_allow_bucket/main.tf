
variable "environment" {
  description = "Deployment env"
}
variable "bucket_name" {
  description = "The name of the bucket"
}
variable "acl" {
  description = "The acl value of the bucket"
}

module "config" {
  source = "github.com/ricsam/serverless_using_terraform//utils/config"
  environment = "${var.environment}"
}

locals {
  full_bucket_name = "${module.config.s3_bucket_name_prefix}${var.bucket_name}"
}


resource "aws_s3_bucket" "cors_allow_bucket" {
  bucket = "${local.full_bucket_name}"
  acl    = "${var.acl}"

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }
}
output "arn" {
  value = "${aws_s3_bucket.cors_allow_bucket.arn}"
}

output "name" {
  value = "${local.full_bucket_name}"
}
