terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.26"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }

  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-west-1"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
name = "${var.azure_resource_group_name}"
location = "${var.azure_region}"
}


#creating AWS LAMBDA FUNCTION
resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "fedex-day-multi-function" {
  filename      = "lambda_function_payload.zip"
  function_name = "fedex-day-multi-function"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "exports.test"

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = filebase64sha256("lambda_function_payload.zip")

  runtime = "nodejs12.x"

}