class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  skip_before_action :verify_authenticity_token
  
  before_action :require_login
  
  helper_method :current_user, :logged_in?, :admin_setting
  
  private
  
  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end
  
  def logged_in?
    !!current_user
  end
  
  def require_login
    unless logged_in?
      respond_to do |format|
        format.html { redirect_to login_path }
        format.json { render json: { success: false, error: 'Authentication required' }, status: 401 }
      end
    end
  end
  
  def require_admin
    unless current_user&.admin?
      redirect_to root_path
    end
  end
  
  def admin_setting
    @admin_setting ||= AdminSetting.first || AdminSetting.new
  end
end
