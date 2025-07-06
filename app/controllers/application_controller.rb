class ApplicationController < ActionController::API
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  
  # JWT token authentication
  include JsonWebToken
  
  private
  
  def authenticate_user!
    token = request.headers['Authorization']&.split(' ')&.last
    return render json: { error: 'Access denied' }, status: 401 unless token
    
    begin
      decoded_token = jwt_decode(token)
      @current_user = User.find(decoded_token[:user_id])
    rescue JWT::DecodeError, ActiveRecord::RecordNotFound
      render json: { error: 'Invalid token' }, status: 401
    end
  end
  
  def current_user
    @current_user
  end
  
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :phone, :role])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :phone, :role])
  end
  
  def render_error(message, status = 422)
    render json: { error: message }, status: status
  end
  
  def render_success(data = {}, message = 'Success')
    render json: { message: message, data: data }, status: 200
  end
end
