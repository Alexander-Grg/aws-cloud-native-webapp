import json

def lambda_handler(event, context):
    print("== Stream processing started")
    
    records = event.get('Records', [])
    
    for record in records:
        event_name = record.get('eventName')
        
        if event_name == 'INSERT':
            new_image = record['dynamodb'].get('NewImage', {})
            # DynamoDB streams use data type keys like 'S' for String
            message_group_uuid = new_image.get('message_group_uuid', {}).get('S', 'Unknown')
            
            print(f"== New message detected in group: {message_group_uuid}")
            # Add any specific stream logic you need here

    return {
        'statusCode': 200,
        'body': json.dumps(f"Successfully processed {len(records)} records.")
    }