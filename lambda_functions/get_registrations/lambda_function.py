import json
import boto3
from decimal import Decimal
from urllib.parse import unquote
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
registrations_table = dynamodb.Table('Registrations')

def lambda_handler(event, context):
    try:
        path_params = event.get('pathParameters') or {}
        raw_email = path_params.get('email')
        email = unquote(raw_email) if raw_email else None

        if not email:
            return response(400, {'error': 'email is required'})

        result = registrations_table.query(
            IndexName='emailIndex',
            KeyConditionExpression=Key('email').eq(email)
        )

        registrations = result.get('Items', [])

        return response(200, {
            'count': len(registrations),
            'registrations': registrations
        })

    except Exception as e:
        print(f'Error: {str(e)}')
        return response(500, {'error': 'Internal server error'})


def decimal_default(obj):
    if isinstance(obj, Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    raise TypeError


def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(body, default=decimal_default)
    }
