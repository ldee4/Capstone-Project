# -----------------------------
# Events Table
# -----------------------------
resource "aws_dynamodb_table" "events" {
  name         = "Events"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "eventsId"

  attribute {
    name = "eventsId"
    type = "S"
  }

  tags = {
    Project = var.project_name
  }
}

# -----------------------------
# Registrations Table
# -----------------------------
resource "aws_dynamodb_table" "registrations" {
  name         = "Registrations"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "registrationsId"

  attribute {
    name = "registrationsId"
    type = "S"
  }

  # Needed so we can query registrations by email
  # (used by GET /registrations/{email})
  attribute {
    name = "email"
    type = "S"
  }

  global_secondary_index {
    name            = "emailIndex"
    hash_key        = "email"
    projection_type = "ALL"
  }

  # Auto-deletes cancelled registrations after the configured retention period.
  # The cancel_registration Lambda writes this field (as a Unix timestamp)
  # when a registration is cancelled.
  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  tags = {
    Project = var.project_name
  }
}
