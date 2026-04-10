import os
import sys

from flask import Flask
from flask import request, g
from lib.cors import init_cors
from prometheus_flask_exporter import PrometheusMetrics

from opentelemetry import trace
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.psycopg import PsycopgInstrumentor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.resources import Resource

import routes.general
import routes.activities
import routes.users
import routes.messages

app = Flask(__name__)

resource = Resource.create({"service.name": "backend-flask"})
provider = TracerProvider(resource=resource)
trace.set_tracer_provider(provider)

otlp_exporter = OTLPSpanExporter()
span_processor = BatchSpanProcessor(otlp_exporter)
provider.add_span_processor(span_processor)

FlaskInstrumentor().instrument_app(app)

PsycopgInstrumentor().instrument()

metrics = PrometheusMetrics(app)
init_cors(app)

metrics.info('app_info', 'Backend Application info', version='1.0.0')

routes.general.load(app)
routes.activities.load(app)
routes.users.load(app)
routes.messages.load(app)

if __name__ == "__main__":
  app.run(debug=True)