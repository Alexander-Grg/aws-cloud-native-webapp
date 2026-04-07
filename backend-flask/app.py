import os
import sys

from flask import Flask
from flask import request, g
from lib.cors import init_cors
from prometheus_flask_exporter import PrometheusMetrics

import routes.general
import routes.activities
import routes.users
import routes.messages

app = Flask(__name__)

metrics = PrometheusMetrics(app)
init_cors(app)

metrics.info('app_info', 'Backend Application info', version='1.0.0')

routes.general.load(app)
routes.activities.load(app)
routes.users.load(app)
routes.messages.load(app)

if __name__ == "__main__":
  app.run(debug=True)