import boto3
import json
import importlib.util
import os
import pytest
from moto import mock_aws


def load_lambda(function_folder):
    """Load a lambda_function.py file as a module, even though
    multiple folders share the same filename."""
    path = os.path.join(
        os.path.dirname(__file__), "..", "lambda_functions",
        function_folder, "lambda_function.py"
    )
    spec = importlib.util.spec_from_file_location(function_folder, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.fixture
def dynamodb_setup():
    """Creates fake Events and Registrations tables in memory using moto."""
    with mock_aws():
        client = boto3.client("dynamodb", region_name="us-east-1")

        client.create_table(
            TableName="Events",
            KeySchema=[{"AttributeName": "eventsId", "KeyType": "HASH"}],
            AttributeDefinitions=[{"AttributeName": "eventsId", "AttributeType": "S"}],
            BillingMode="PAY_PER_REQUEST",
        )

        client.create_table(
            TableName="Registrations",
            KeySchema=[{"AttributeName": "registrationsId", "KeyType": "HASH"}],
            AttributeDefinitions=[
                {"AttributeName": "registrationsId", "AttributeType": "S"},
                {"AttributeName": "email", "AttributeType": "S"},
            ],
            BillingMode="PAY_PER_REQUEST",
            GlobalSecondaryIndexes=[{
                "IndexName": "emailIndex",
                "KeySchema": [{"AttributeName": "email", "KeyType": "HASH"}],
                "Projection": {"ProjectionType": "ALL"},
            }],
        )

        yield client


def test_list_events_empty(dynamodb_setup):
    list_events = load_lambda("list_events")
    result = list_events.lambda_handler({}, {})
    body = json.loads(result["body"])

    assert result["statusCode"] == 200
    assert body["count"] == 0


def test_register_missing_fields(dynamodb_setup):
    register = load_lambda("register")
    event = {"body": json.dumps({"name": "Test User"})}  # missing email + eventsId
    result = register.lambda_handler(event, {})
    body = json.loads(result["body"])

    assert result["statusCode"] == 400
    assert "error" in body


def test_register_event_not_found(dynamodb_setup):
    register = load_lambda("register")
    event = {
        "body": json.dumps({
            "name": "Test User",
            "email": "test@example.com",
            "eventsId": "nonexistent-event"
        })
    }
    result = register.lambda_handler(event, {})
    body = json.loads(result["body"])

    assert result["statusCode"] == 404
    assert body["error"] == "Event not found"


def test_register_success(dynamodb_setup):
    # First, add a test event to the fake table
    dynamodb_setup.put_item(
        TableName="Events",
        Item={
            "eventsId": {"S": "event-001"},
            "name": {"S": "Test Event"},
            "availableSeats": {"N": "10"},
        }
    )

    register = load_lambda("register")
    event = {
        "body": json.dumps({
            "name": "Test User",
            "email": "test@example.com",
            "eventsId": "event-001"
        })
    }
    result = register.lambda_handler(event, {})
    body = json.loads(result["body"])

    assert result["statusCode"] == 201
    assert "registrationId" in body