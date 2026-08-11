<<<<<<< HEAD
# Event Registration & Ticketing System

A serverless REST API built on AWS that replaces manual event registration processes (e.g. Microsoft Forms + Excel) with a scalable, automated, cloud-native solution.

**Live demo:** http://event-ticketing-frontend-erica.s3-website-us-east-1.amazonaws.com
**Repository:** https://github.com/myzz-rica/event-registration-ticketing-system

Built by **Erica Gyamfuaa Fordjour** as a capstone project.

---

## Problem

Manual event registration through forms and spreadsheets doesn't scale. There's no real-time seat tracking, no automated confirmation, no audit trail, and no way to programmatically integrate registration into other tools. This project replaces that process with a serverless REST API that any frontend (web, mobile, or third-party) can call.

---

## Architecture

```
Browser / Frontend (S3 static website)
          │
          ▼
   API Gateway (REST API)
          │
          ▼
   AWS Lambda (4 functions, Python)
          │
          ▼
     DynamoDB (Events, Registrations)
          │
          ▼
   CloudWatch (Logs + Alarms) ── SNS (email alerts)

GitHub ──push──▶ GitHub Actions ──OIDC──▶ AWS (test, then auto-deploy)
```

**Services used:**
- **API Gateway** — REST API, routes HTTP requests to Lambda
- **AWS Lambda** — business logic (Python 3.14)
- **DynamoDB** — Events and Registrations tables, on-demand billing
- **CloudWatch** — logging and error-rate alarms
- **SNS** — email notifications when error rate exceeds 5%
- **AWS Budgets** — zero-spend budget to stay within Free Tier
- **S3** — static website hosting for the frontend
- **GitHub Actions** — automated testing and deployment via OIDC (no stored AWS keys)

---

## API Endpoints

| Method | Path | Description |
|---|---|---|
| `POST` | `/register` | Register for an event |
| `GET` | `/events` | List all events |
| `GET` | `/registrations/{email}` | View all registrations for an email |
| `DELETE` | `/registration/{id}` | Cancel a registration |

### Example: Register

```
POST /register
Content-Type: application/json

{
  "name": "Erica Fordjour",
  "email": "erica@example.com",
  "eventsId": "event-001"
}
```

Response:
```json
{
  "message": "Registration successful",
  "registrationId": "614706c4-737c-445a-a2bc-21aa7c4355aa"
}
```

---

## Data Model

**Events table**
| Field | Type | Notes |
|---|---|---|
| `eventsId` (PK) | String | Unique event ID |
| `name` | String | Event name |
| `date` | String | Event date |
| `location` | String | Event location |
| `capacity` | Number | Max seats |
| `availableSeats` | Number | Seats remaining |

**Registrations table**
| Field | Type | Notes |
|---|---|---|
| `registrationsId` (PK) | String | Unique registration ID |
| `email` | String | Indexed via `emailIndex` (GSI) for lookups |
| `eventsId` | String | Which event |
| `name` | String | Registrant name |
| `status` | String | `confirmed` or `cancelled` |
| `registeredAt` | String | ISO timestamp |
| `expiresAt` | Number | TTL — set on cancellation, auto-deletes record 30 days later |

---

## Security & Monitoring

- **Least privilege IAM** — a dedicated Lambda execution role with permissions scoped to exactly the two DynamoDB tables and index it needs (no wildcard access, no admin actions).
- **Input validation** — required-field checks and basic email format validation on registration; existence checks before update/delete operations.
- **CloudWatch Alarms** — one alarm per Lambda function, triggers if the error rate (`Errors ÷ Invocations`) exceeds 5%, notifying via SNS email.
- **CloudWatch Logs** — every function logs execution details and errors automatically.
- **AWS Budgets** — a zero-spend budget alerts on any charge above $0, keeping the project inside Free Tier.
- **CI/CD via OIDC** — GitHub Actions authenticates to AWS using short-lived, per-run tokens (OpenID Connect) instead of stored access keys, scoped to this repository only via the IAM role's trust policy.

---

## CI/CD Pipeline

Every push to `main` triggers `.github/workflows/test-lambda.yml`:

1. **Test job** — installs dependencies, runs `pytest` against the four Lambda functions using `moto` to simulate DynamoDB (no real AWS resources touched).
2. **Deploy job** — runs only if tests pass. Authenticates to AWS via OIDC, zips each function's code, and deploys it directly with `aws lambda update-function-code`.

This means the GitHub repository is the single source of truth — whatever is in `main` is what's live in AWS.

---

## Local Setup / Reproducing This Project

```
event-registration-ticketing-system/
├── .github/workflows/test-lambda.yml   # CI/CD pipeline
├── lambda_functions/
│   ├── register/lambda_function.py
│   ├── list_events/lambda_function.py
│   ├── get_registrations/lambda_function.py
│   └── cancel_registration/lambda_function.py
├── frontend/index.html                 # Demo UI, hosted on S3
├── tests/test_lambda_functions.py      # pytest + moto tests
├── requirements.txt
└── README.md
```

1. Clone the repo.
2. Create the two DynamoDB tables (`Events`, `Registrations` with `emailIndex` GSI) and enable TTL on `expiresAt`.
3. Create an IAM role for Lambda with least-privilege access to those tables.
4. Create the four Lambda functions, using the code in `lambda_functions/`.
5. Wire up API Gateway routes matching the table above, with Lambda proxy integration and CORS enabled.
6. Deploy the API to a stage.
7. Set `API_BASE` in `frontend/index.html` to your API Gateway invoke URL.
8. Host `frontend/index.html` on S3 with static website hosting enabled.

---


## Infrastructure as Code

The `infrastructure/` folder contains a Terraform configuration that codifies this project's AWS resources — DynamoDB tables, IAM roles/policies, Lambda functions, API Gateway routes, CloudWatch alarms, and the SNS topic — as an alternative to the manual console setup described above.

**Note:** This configuration mirrors the live, manually-built infrastructure but has not been applied against AWS. It's included as documentation of the full architecture and a foundation for infrastructure automation, rather than as a tested deployment path. Review it carefully (`terraform plan`) before running `terraform apply`, ideally against a separate AWS account to avoid conflicting with existing resources of the same name.


## Testing

Run tests locally:
```bash
pip install -r requirements.txt
pytest tests/ -v
```

Manual testing was also performed via Postman for all four endpoints, and end-to-end through the live frontend (register → seat count updates → lookup → cancel → seat returned).

---

## Cost Optimization

Every service in this architecture is pay-per-use:
- Lambda: charged only per invocation, no idle cost
- DynamoDB: on-demand billing, no fixed capacity
- API Gateway: charged per API call
- S3 static hosting: negligible cost at this scale

A zero-spend AWS Budget monitors the account and alerts immediately if any charge occurs, keeping the project within AWS Free Tier.

---

## Known Limitations / Future Improvements

- No admin/organizer endpoint for creating events via the API (currently done manually via the DynamoDB console).
- IAM role is shared across all four Lambda functions; a stricter setup would give each function its own narrowly-scoped role.
- No authentication on API endpoints — appropriate for a capstone demo, but a production version would add API keys or a proper auth layer (e.g. Amazon Cognito).
- SNS alerts are email-only; could be extended to Slack/SMS.

---

## Challenges Solved

A few real issues encountered and resolved during development, useful context for anyone reviewing this project:
- DynamoDB returns numbers as `Decimal`, which isn't natively JSON-serializable — solved with a custom JSON encoder.
- Email addresses arrived URL-encoded (`%40` instead of `@`) in path parameters — solved with `urllib.parse.unquote`.
- GitHub's OIDC subject claim format changed to include immutable owner/repo IDs for newer repositories — trust policy updated accordingly.
- Repository-level "Workflow permissions" setting silently capped the `id-token: write` permission needed for OIDC, despite it being correctly declared in the workflow file.
=======
# Capstone-Project
>>>>>>> 7295d1eeead32e3817867a11e43f0c4e40c8b307
