class Franchise::BaseController < ApplicationController
  skip_before_action :require_login
  before_action :require_franchise_login
  layout 'franchise'

  private

  def current_franchise
    @current_franchise ||= Franchise.find(session[:franchise_id]) if session[:franchise_id]
  end
  helper_method :current_franchise

  def require_franchise_login
    unless current_franchise
      redirect_to franchise_login_path, notice: 'Please log in to continue.'
    end
  end

  def franchise_logged_in?
    !!current_franchise
  end
  helper_method :franchise_logged_in?
end