import json
import psycopg2
import os
import boto3

def get_secret():
    secret_arn = os.environ['RDS_SECRET_ARN']
    client = boto3.client('secretsmanager')
    response = client.get_secret_value(SecretId=secret_arn)
    return json.loads(response['SecretString'])

def lambda_handler(event, context):
    print('== Connection starting...')
    user_attrs = event['request']['userAttributes']
    
    user_display_name = user_attrs.get('name', 'No Name')
    user_email        = user_attrs.get('email')
    user_cognito_id   = event.get('userName') 
    user_handle       = user_attrs.get('preferred_username', user_email.split('@')[0] if user_email else 'unknown')

    if not user_email:
        print("ERROR: Missing email in Cognito attributes.")
        return event

    conn = None
    try:
        print('== Fetching DB credentials from Secrets Manager...')
        secrets = get_secret()
        
        print('== Connecting to DB...')
        conn = psycopg2.connect(
            host=secrets['host'],
            port=secrets['port'],
            dbname=secrets['dbname'],
            user=secrets['username'],
            password=secrets['password']
        )
        cur = conn.cursor()
        
        sql = """
            INSERT INTO public.users (display_name, email, handle, cognito_user_id) 
            VALUES(%s, %s, %s, %s)
            ON CONFLICT (handle) 
            DO UPDATE SET 
                cognito_user_id = EXCLUDED.cognito_user_id,
                email = EXCLUDED.email;
        """
        
        cur.execute(sql, [user_display_name, user_email, user_handle, user_cognito_id])
        conn.commit()
        print("== User successfully synced.")

    except Exception as error:
        print("== Error:", error)
    finally:
        if conn is not None:
            cur.close()
            conn.close()

    # Cognito requires the event to be returned
    return event