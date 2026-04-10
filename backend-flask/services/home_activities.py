from datetime import datetime, timedelta, timezone
from opentelemetry import trace
from lib.db import db

tracer = trace.get_tracer(__name__)

class HomeActivities:
    def run(cognito_user_id=None):
        with tracer.start_as_current_span("HomeActivities.run") as span:
            
            span.set_attribute("app.cognito_user_id", str(cognito_user_id))
            
            print(f"DEBUG: HomeActivities.run() called with cognito_user_id={cognito_user_id}")
            
            sql = db.template('activities', 'home')
            print(f"DEBUG: RAW SQL Template:")
            print("=" * 50)
            print(sql)
            print("=" * 50)
            
            params = {
                'cognito_user_id': cognito_user_id
            }
            print(f"DEBUG: Params: {params}")

            results = db.query_array_json(sql, params)

            span.set_attribute("app.results_count", len(results) if results else 0)
            print(f"DEBUG: Query returned {len(results) if results else 0} results")
            
            return results