variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used for naming Lambda functions and related resources"
  type        = string
  default     = "EventRegAndTicketing"
}

variable "api_stage_name" {
  description = "API Gateway deployment stage name"
  type        = string
  default     = "SystemDev"
}

variable "cancelled_registration_ttl_days" {
  description = "How many days after cancellation a registration record auto-expires"
  type        = number
  default     = 30
}

variable "error_rate_alarm_threshold" {
  description = "Error rate percentage that triggers a CloudWatch alarm"
  type        = number
  default     = 5
}

variable "alert_email" {
  description = "Email address to receive SNS alerts (CloudWatch alarms + Budgets)"
  type        = string
}
