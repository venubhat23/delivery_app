class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  skip_before_action :verify_authenticity_token

  before_action :require_login
  
  helper_method :current_user, :logged_in?, :admin_setting, :current_franchise, :franchise_logged_in?, :current_user_type, :current_affiliate, :affiliate_logged_in?

  private

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end

  def current_franchise
    @current_franchise ||= Franchise.find(session[:franchise_id]) if session[:franchise_id]
  end

  def current_affiliate
    @current_affiliate ||= Affiliate.find(session[:affiliate_id]) if session[:affiliate_id]
  end

  def logged_in?
    !!current_user || !!current_franchise || !!current_affiliate
  end

  def franchise_logged_in?
    !!current_franchise
  end

  def affiliate_logged_in?
    !!current_affiliate
  end

  def current_user_type
    if current_affiliate
      'affiliate'
    elsif current_franchise
      'franchise'
    elsif current_user
      'admin'
    else
      nil
    end
  end

  def require_login
    unless logged_in?
      respond_to do |format|
        format.html { redirect_to login_path }
        format.json { render json: { success: false, error: 'Authentication required' }, status: 401 }
        format.pdf { redirect_to login_path }
        format.any { redirect_to login_path }
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
