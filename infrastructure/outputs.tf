output "api_base_url" {
  description = "The base URL to use as API_BASE in frontend/index.html"
  value       = aws_api_gateway_stage.this.invoke_url
}

output "events_table_name" {
  value = aws_dynamodb_table.events.name
}

output "registrations_table_name" {
  value = aws_dynamodb_table.registrations.name
}

output "lambda_function_names" {
  value = { for k, fn in aws_lambda_function.functions : k => fn.function_name }
}

output "github_actions_deploy_role_arn" {
  description = "Set this as the AWS_ROLE_ARN secret in your GitHub repository"
  value       = aws_iam_role.github_actions_deploy.arn
}

output "sns_alert_topic_arn" {
  value = aws_sns_topic.alerts.arn
}
