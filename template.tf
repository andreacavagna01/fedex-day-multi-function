terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.26"
    }

    aws = {
      source = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

########################################################################################################################

# Configure the AWS Provider
provider "aws" {
  region = "eu-west-1"
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
  type = "zip"
  output_path = "/tmp/lambda_zip_file_int.zip"
  source_dir = "src/"
}

resource "aws_lambda_function" "fedex-day-multi-function" {
  function_name = "fedex-day-multi-function"
  role = aws_iam_role.iam_for_lambda.arn
  handler = "function.lambda_handler"
  filename = data.archive_file.lambda_zip_file_int.output_path
  source_code_hash = data.archive_file.lambda_zip_file_int.output_base64sha256
  layers = "arn:aws:lambda:eu-west-1:634166935893:layer:vault-lambda-extension:6"
  runtime = "python3.7"
  # ... other configuration ...
  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.example,
  ]
}

# This is to optionally manage the CloudWatch Log Group for the Lambda Function.
# If skipping this resource configuration, also add "logs:CreateLogGroup" to the IAM policy below.
resource "aws_cloudwatch_log_group" "example" {
  name              = "/aws/lambda/fedex-day-multi-function"
  retention_in_days = 14
}

# See also the following AWS managed policy: AWSLambdaBasicExecutionRole
resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

########################################################################################################################

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name = "fdmfrg"
  location = "northeurope"
}
resource "random_string" "storage_name" {
  length = 16
  special = false
  upper = false
}
resource "random_string" "function_name" {
  length = 16
  special = false
  upper = false
}
resource "random_string" "app_service_plan_name" {
  length = 16
  special = false
}
resource "azurerm_storage_account" "storage" {
  name = "${random_string.storage_name.result}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location = "${azurerm_resource_group.rg.location}"
  account_tier = "Standard"
  account_replication_type = "LRS"
}
resource "azurerm_storage_container" "storage_container" {
  name = "func"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  storage_account_name = "${azurerm_storage_account.storage.name}"
  container_access_type = "private"
}

resource "azurerm_storage_blob" "storage_blob" {
  name = "azure.zip"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  storage_account_name = "${azurerm_storage_account.storage.name}"
  storage_container_name = "${azurerm_storage_container.storage_container.name}"
  type = "block"
  source = "./dist/azure.zip"
}
data "azurerm_storage_account_sas" "storage_sas" {
  connection_string = "${azurerm_storage_account.storage.primary_connection_string}"
  https_only = false
  resource_types {
    service = false
    container = false
    object = true
  }
  services {
    blob = true
    queue = false
    table = false
    file = false
  }
  start = "2018–03–21"
  expiry = "2028–03–21"
  permissions {
    read = true
    write = false
    delete = false
    list = false
    add = false
    create = false
    update = false
    process = false
  }
}

resource "azurerm_app_service_plan" "plan" {
  name = "${random_string.app_service_plan_name.result}"
  location = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  kind = "functionapp"
  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_function_app" "function" {
  name = "${random_string.storage_name.result}"
  location = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  app_service_plan_id = "${azurerm_app_service_plan.plan.id}"
  storage_connection_string = "${azurerm_storage_account.storage.primary_connection_string}"
  version = "~2"
  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "dotnet"
    "FUNCTION_APP_EDIT_MODE" = "readonly"
    "https_only" = true
    "HASH" = "${base64sha256(file("./dist/azure.zip"))}"
    "WEBSITE_RUN_FROM_PACKAGE" = "https://${azurerm_storage_account.storage.name}.blob.core.windows.net/${azurerm_storage_container.storage_container.name}/${azurerm_storage_blob.storage_blob.name}${data.azurerm_storage_account_sas.storage_sas.sas}"
  }
}
