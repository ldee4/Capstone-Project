resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-Alerts-Topics"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# One error-rate alarm per function, using metric math: (Errors / Invocations) * 100
resource "aws_cloudwatch_metric_alarm" "error_rate" {
  for_each = local.lambda_functions

  alarm_name          = "${var.project_name}-${each.key}-ErrorRate-Alarm"
  alarm_description   = "Triggers when ${each.key} function error rate exceeds ${var.error_rate_alarm_threshold}%"
  comparison_operator = "GreaterThanThreshold"
  threshold            = var.error_rate_alarm_threshold
  evaluation_periods   = 1
  datapoints_to_alarm  = 1
  treat_missing_data   = "notBreaching"

  metric_query {
    id          = "e1"
    expression  = "(m1/m2)*100"
    label       = "ErrorRatePercent"
    return_data = true
  }

  metric_query {
    id = "m1"
    metric {
      namespace   = "AWS/Lambda"
      metric_name = "Errors"
      period      = 300
      stat        = "Sum"
      dimensions = {
        FunctionName = aws_lambda_function.functions[each.key].function_name
      }
    }
  }

  metric_query {
    id = "m2"
    metric {
      namespace   = "AWS/Lambda"
      metric_name = "Invocations"
      period      = 300
      stat        = "Sum"
      dimensions = {
        FunctionName = aws_lambda_function.functions[each.key].function_name
      }
    }
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}
