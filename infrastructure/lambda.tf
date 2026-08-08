locals {
  lambda_functions = {
    Register = {
      source_dir = "../lambda_functions/register"
    }
    ListEvents = {
      source_dir = "../lambda_functions/list_events"
    }
    GetRegistrations = {
      source_dir = "../lambda_functions/get_registrations"
    }
    CancelRegistration = {
      source_dir = "../lambda_functions/cancel_registration"
    }
  }
}

# Zips each function's source folder at plan/apply time
data "archive_file" "lambda_zip" {
  for_each    = local.lambda_functions
  type        = "zip"
  source_dir  = each.value.source_dir
  output_path = "${path.module}/build/${each.key}.zip"
}

resource "aws_lambda_function" "functions" {
  for_each = local.lambda_functions

  function_name = "${var.project_name}-${each.key}"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.13"
  timeout       = 10
  memory_size   = 128

  filename         = data.archive_file.lambda_zip[each.key].output_path
  source_code_hash = data.archive_file.lambda_zip[each.key].output_base64sha256

  tags = {
    Project = var.project_name
  }
}

# Allows API Gateway to invoke each Lambda function
resource "aws_lambda_permission" "api_gateway_invoke" {
  for_each = local.lambda_functions

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.functions[each.key].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}
