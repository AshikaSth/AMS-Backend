
class ApplicationController < ActionController::API

  include Pundit::Authorization
  include ActionController::Cookies
  include ErrorFormatter

  before_action :authorize_request, except: []
  attr_reader :current_user

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private
  def pundit_user
    @current_user
  end


  def authorize_request
    token = cookies.signed[:access_token]
    unless token
      return render json: {
        errors: [{ field: 'token', message: 'Access token is missing', type: 'authentication_error' }]
      }, status: :unauthorized
    end
    payload = JsonWebToken.decode(token)

    if payload && payload["type"] == "access"
      @current_user = User.find_by(id: payload["user_id"])
    end

    unless @current_user
      render json: {
        errors: [{ field: 'token', message: 'Invalid or expired access token', type: 'authentication_error' }]
    }, status: :unauthorized
    end
  end

  def record_not_found(exception)
    render json: {
      errors: [{
        field: exception.model.downcase,
        message: "#{exception.model} not found",
        type: 'not_found'
      }]
    }, status: :not_found
  end

  def user_not_authorized
    render json: {
      errors: [{
        field: 'authorization',
        message: 'You are not authorized to perform this action',
        type: 'authorization_error'
      }]
    }, status: :forbidden
  end
end
