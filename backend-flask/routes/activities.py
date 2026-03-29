## flask
from flask import request, g

## decorators
from lib.cognito_jwt_token import jwt_required
from flask_cors import cross_origin

## services
from services.home_activities import *
from services.notifications_activities import *
from services.create_activity import *
from services.search_activities import *
from services.create_reply import *
from services.show_activity import *

## helpers
from lib.helpers import model_json

def load(app):
  def default_home_feed(e):
    app.logger.debug(e)
    app.logger.debug("unauthenicated")
    data = HomeActivities.run()
    return data, 200

  @app.route("/api/activities/home", methods=['GET'])
  @jwt_required(on_error=default_home_feed)
  def data_home():
    data = HomeActivities.run(cognito_user_id=g.cognito_user_id)
    return data, 200

  @app.route("/api/activities/notifications", methods=['GET'])
  def data_notifications():
    data = NotificationsActivities.run()
    return data, 200

  @app.route("/api/activities/search", methods=['GET'])
  def data_search():
    term = request.args.get('term')
    model = SearchActivities.run(term)
    return model_json(model)

  @app.route("/api/activities/<string:activity_uuid>", methods=['GET', 'OPTIONS'])
  @cross_origin()
  def data_activity_show(activity_uuid):
    data = ShowActivity.run(activity_uuid=activity_uuid)
    return data, 200

  @app.route("/api/activities", methods=['POST','OPTIONS'])
  @cross_origin()
  @jwt_required()
  def data_activities():
    data = request.get_json(force=True, silent=True) or {}
    message = data.get('message')
    ttl = data.get('ttl')
    
    model = CreateActivity.run(message, g.cognito_user_id, ttl)
    
    if model['errors'] is not None and len(model['errors']) > 0:
      return model['errors'], 422
    else:
      return model['data'], 200

  @app.route("/api/activities/<string:activity_uuid>/reply", methods=['POST','OPTIONS'])
  @cross_origin()
  @jwt_required()
  def data_activities_reply(activity_uuid):
    data = request.get_json(force=True, silent=True) or {}
    message = data.get('message')
    
    model = CreateReply.run(message, g.cognito_user_id, activity_uuid)

    if model['errors'] is not None and len(model['errors']) > 0:
      return model['errors'], 422
    else:
      return model['data'], 200