import json
import boto3
import uuid
from decimal import Decimal
from datetime import datetime, timezone

dynamodb = boto3.resource('dynamodb')
events_table = dynamodb.Table('Events')
registrations_table = dynamodb.Table('Registrations')

def lambda_handler(event, context):
    try:
        body = json.loads(event.get('body', '{}'))

        name = body.get('name')
        email = body.get('email')
        event_id = body.get('eventsId')

        if not name or not email or not event_id:
            return response(400, {'error': 'name, email, and eventsId are required'})

        event_result = events_table.get_item(Key={'eventsId': event_id})
        if 'Item' not in event_result:
            return response(404, {'error': 'Event not found'})

        event_item = event_result['Item']

        if event_item.get('availableSeats', 0) <= 0:
            return response(400, {'error': 'Event is fully booked'})

        registration_id = str(uuid.uuid4())
        registrations_table.put_item(Item={
            'registrationsId': registration_id,
            'email': email,
            'name': name,
            'eventsId': event_id,
            'status': 'confirmed',
            'registeredAt': datetime.now(timezone.utc).isoformat()
        })

        events_table.update_item(
            Key={'eventsId': event_id},
            UpdateExpression='SET availableSeats = availableSeats - :dec',
            ConditionExpression='availableSeats > :zero',
            ExpressionAttributeValues={':dec': 1, ':zero': 0}
        )

        return response(201, {
            'message': 'Registration successful',
            'registrationId': registration_id
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