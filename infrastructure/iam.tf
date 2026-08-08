# -----------------------------
# Lambda execution role
# -----------------------------
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-Lambda-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Lets Lambda write logs to CloudWatch — required for every function
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Scoped DynamoDB access — only the actions and tables Lambda actually needs
resource "aws_iam_role_policy" "dynamodb_access" {
  name = "${var.project_name}-DynamoDB-Access"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.events.arn,
          aws_dynamodb_table.registrations.arn,
          "${aws_dynamodb_table.registrations.arn}/index/emailIndex"
        ]
      }
    ]
  })
}

# -----------------------------
# GitHub Actions OIDC provider + deploy role
# -----------------------------
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

variable "github_owner" {
  description = "GitHub username or org that owns the repository"
  type        = string
  default     = "myzz-rica"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "event-registration-ticketing-system"
}

resource "aws_iam_role" "github_actions_deploy" {
  name = "GitHubActions-Deploy-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Note: GitHub repositories created after July 2026 issue OIDC tokens
            # using an immutable "owner@ownerId/repo@repoId" subject format instead
            # of the plain "owner/repo" format. If deploys fail with
            # "Not authorized to perform sts:AssumeRoleWithWebIdentity" even though
            # this looks correct, check your repo's actual token format and update
            # this condition to match (e.g. "repo:owner@123/repo@456:*").
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_owner}/${var.github_repo}:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_actions_lambda_deploy" {
  name = "GitHubActions-LambdaDeploy-Policy"
  role = aws_iam_role.github_actions_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["lambda:UpdateFunctionCode"]
        Resource = [for fn in aws_lambda_function.functions : fn.arn]
      }
    ]
  })
}
