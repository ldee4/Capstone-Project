resource "aws_api_gateway_rest_api" "this" {
  name = "EventTicketingAPI"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# -----------------------------
# /events  (GET -> ListEvents)
# -----------------------------
resource "aws_api_gateway_resource" "events" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "events"
}

module "events_get" {
  source       = "./modules/api_method"
  rest_api_id  = aws_api_gateway_rest_api.this.id
  resource_id  = aws_api_gateway_resource.events.id
  http_method  = "GET"
  function_arn = aws_lambda_function.functions["ListEvents"].invoke_arn
}

# -----------------------------
# /register  (POST -> Register)
# -----------------------------
resource "aws_api_gateway_resource" "register" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "register"
}

module "register_post" {
  source       = "./modules/api_method"
  rest_api_id  = aws_api_gateway_rest_api.this.id
  resource_id  = aws_api_gateway_resource.register.id
  http_method  = "POST"
  function_arn = aws_lambda_function.functions["Register"].invoke_arn
}

# -----------------------------
# /registrations/{email}  (GET -> GetRegistrations)
# -----------------------------
resource "aws_api_gateway_resource" "registrations" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "registrations"
}

resource "aws_api_gateway_resource" "registrations_email" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.registrations.id
  path_part   = "{email}"
}

module "registrations_email_get" {
  source       = "./modules/api_method"
  rest_api_id  = aws_api_gateway_rest_api.this.id
  resource_id  = aws_api_gateway_resource.registrations_email.id
  http_method  = "GET"
  function_arn = aws_lambda_function.functions["GetRegistrations"].invoke_arn
}

# -----------------------------
# /registration/{id}  (DELETE -> CancelRegistration)
# Note: singular "registration", distinct from plural "registrations" above
# -----------------------------
resource "aws_api_gateway_resource" "registration" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "registration"
}

resource "aws_api_gateway_resource" "registration_id" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.registration.id
  path_part   = "{id}"
}

module "registration_id_delete" {
  source       = "./modules/api_method"
  rest_api_id  = aws_api_gateway_rest_api.this.id
  resource_id  = aws_api_gateway_resource.registration_id.id
  http_method  = "DELETE"
  function_arn = aws_lambda_function.functions["CancelRegistration"].invoke_arn
}

# -----------------------------
# Deployment + stage
# -----------------------------
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = sha1(jsonencode([
      module.events_get.method_id,
      module.register_post.method_id,
      module.registrations_email_get.method_id,
      module.registration_id_delete.method_id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "this" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = var.api_stage_name
}
