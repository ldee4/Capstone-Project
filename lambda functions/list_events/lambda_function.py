import json
import boto3
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
events_table = dynamodb.Table('Events')

def lambda_handler(event, context):
    try:
        result = events_table.scan()
        events = result.get('Items', [])

        return response(200, {
            'count': len(events),
            'events': events
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