import json
import boto3
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
registrations_table = dynamodb.Table('Registrations')
events_table = dynamodb.Table('Events')

def lambda_handler(event, context):
    try:
        path_params = event.get('pathParameters') or {}
        registration_id = path_params.get('id')

        if not registration_id:
            return response(400, {'error': 'registration id is required'})

        result = registrations_table.get_item(Key={'registrationsId': registration_id})
        if 'Item' not in result:
            return response(404, {'error': 'Registration not found'})

        registration = result['Item']

        registrations_table.update_item(
            Key={'registrationsId': registration_id},
            UpdateExpression='SET #s = :cancelled',
            ExpressionAttributeNames={'#s': 'status'},
            ExpressionAttributeValues={':cancelled': 'cancelled'}
        )

        events_table.update_item(
            Key={'eventsId': registration['eventsId']},
            UpdateExpression='SET availableSeats = availableSeats + :inc',
            ExpressionAttributeValues={':inc': 1}
        )

        return response(200, {'message': 'Registration cancelled'})

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