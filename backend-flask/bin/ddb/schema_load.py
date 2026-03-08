#!/usr/bin/env python3
import boto3
import sys
import os
from botocore.exceptions import ClientError

attrs = {
  'endpoint_url': os.getenv("AWS_ENDPOINT_URL")
}

if len(sys.argv) == 2:
  if "prod" in sys.argv[1]:
    attrs = {}

dynamodb = boto3.client('dynamodb', **attrs)
table_name = 'webapp-messages'

table_schema = {
  'AttributeDefinitions': [
    {'AttributeName': 'message_group_uuid', 'AttributeType': 'S'},
    {'AttributeName': 'pk', 'AttributeType': 'S'},
    {'AttributeName': 'sk', 'AttributeType': 'S'}
  ],
  'KeySchema': [
    {'AttributeName': 'pk', 'KeyType': 'HASH'},
    {'AttributeName': 'sk', 'KeyType': 'RANGE'}
  ],
  'BillingMode': 'PROVISIONED',
  'ProvisionedThroughput': {
      'ReadCapacityUnits': 5,
      'WriteCapacityUnits': 5
  },
  'GlobalSecondaryIndexes':[{
    'IndexName':'message-group-sk-index',
    'KeySchema':[
      {'AttributeName': 'message_group_uuid', 'KeyType': 'HASH'},
      {'AttributeName': 'sk', 'KeyType': 'RANGE'}
    ],
    'Projection': {
      'ProjectionType': 'ALL'
    },
    'ProvisionedThroughput': {
      'ReadCapacityUnits': 5,
      'WriteCapacityUnits': 5
    },
  }]
}

try:
    response = dynamodb.create_table(
        TableName=table_name,
        **table_schema
    )
    print(f"Table '{table_name}' created successfully.")
    print(response)
except ClientError as e:
    if e.response['Error']['Code'] == 'ResourceInUseException':
        print(f"Table '{table_name}' already exists. Skipping creation.")
    else:
        raise