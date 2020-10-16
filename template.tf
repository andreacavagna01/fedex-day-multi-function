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

  runtime = "python3.7"
}

########################################################################################################################

provider "azurerm" {
  features {}
}

variable "prefix" {
  type    =   string
  default = "fdmf"
}

variable "location" {
  type    =   string
  default = "northeurope"
}

resource "azurerm_resource_group" "funcdeploy" {
  name = "rg-${var.prefix}-function"
  location = var.location
}

resource "azurerm_storage_account" "funcdeploy" {
  name = "${var.prefix}storage"
  resource_group_name = azurerm_resource_group.funcdeploy.name
  location  = azurerm_resource_group.funcdeploy.location
  account_tier = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "funcdeploy" {
  name = "contents"
  storage_account_name = azurerm_storage_account.funcdeploy.name
  container_access_type = "private"
}

resource "azurerm_application_insights" "funcdeploy" {
  name = "${var.prefix}-appinsights"
  location = azurerm_resource_group.funcdeploy.location
  resource_group_name = azurerm_resource_group.funcdeploy.name
  application_type = "web"

  # https://github.com/terraform-providers/terraform-provider-azurerm/issues/1303
  tags = {
    "hidden-link:${azurerm_resource_group.funcdeploy.id}/providers/Microsoft.Web/sites/${var.prefix}func" = "Resource"
  }
}

resource "azurerm_app_service_plan" "funcdeploy" {
  name = "${var.prefix}-functions-consumption-asp"
  location = azurerm_resource_group.funcdeploy.location
  resource_group_name = azurerm_resource_group.funcdeploy.name
  kind = "FunctionApp"
  reserved = true

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

data "archive_file" "azure_function_zip_file_int" {
  type = "zip"
  output_path = "/tmp/azure_function_zip_file_int.zip"
  source {
    content = file("src/function.py")
    filename = "function.py"
  }
}

resource "random_string" "storage_name" {
  length = 16
  special = false
  upper = false
}

resource "azurerm_function_app" "function" {
  name = "${var.prefix}func"
  location = azurerm_resource_group.funcdeploy.location
  resource_group_name = azurerm_resource_group.funcdeploy.name
  app_service_plan_id = azurerm_app_service_plan.funcdeploy.id
  storage_account_name = azurerm_storage_account.funcdeploy.name
  storage_account_access_key = azurerm_storage_account.funcdeploy.primary_access_key
  os_type = "linux"
  version = "~3"
  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "python"
    "FUNCTION_APP_EDIT_MODE" = "readonly"
    "FUNCTIONS_EXTENSION_VERSION" : "~3",
    "https_only" = true,
  }
  provisioner "local-exec" {
    command = "az webapp deployment source config-zip --resource-group ${azurerm_resource_group.funcdeploy.name} --name fdmffunc --src ${data.archive_file.azure_function_zip_file_int.output_path}"
  }
}
