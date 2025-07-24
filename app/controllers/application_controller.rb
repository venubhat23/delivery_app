class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  skip_before_action :verify_authenticity_token
  
  before_action :require_login
  
  helper_method :current_user, :logged_in?
  
  private
  
  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end
  
  def logged_in?
    !!current_user
  end
  
  def require_login
    unless logged_in?
      flash[:alert] = "Please log in to access this page"
      redirect_to login_path
    end
  end
  
  def require_admin
    unless current_user&.admin?
      flash[:alert] = "Access denied. Admin privileges required."
      redirect_to root_path
    end
  end
end
