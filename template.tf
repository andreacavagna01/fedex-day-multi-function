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

data "archive_file" "lambda_zip_file_int" {
  type        = "zip"
  output_path = "/tmp/lambda_zip_file_int.zip"
  source {
    content  = file("src/function.py")
    filename = "function.py"
  }
}

resource "aws_lambda_function" "fedex-day-multi-function" {
  function_name = "fedex-day-multi-function"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "function.lambda_handler"
  filename         = data.archive_file.lambda_zip_file_int.output_path
  source_code_hash = data.archive_file.lambda_zip_file_int.output_base64sha256

  runtime = "python3.7"


}