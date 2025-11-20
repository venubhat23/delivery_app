class Franchise::SessionsController < ApplicationController
  skip_before_action :require_login
  layout 'franchise'

  def new
    redirect_to franchise_dashboard_path if current_franchise
  end

  def create
    franchise = Franchise.find_by(email: params[:email])

    if franchise && franchise.authenticate(params[:password])
      if franchise.active?
        session[:franchise_id] = franchise.id
        flash[:notice] = "Welcome back, #{franchise.name}!"
        redirect_to franchise_dashboard_path
      else
        flash.now[:alert] = 'Your franchise account is inactive. Please contact admin.'
        render :new
      end
    else
      flash.now[:alert] = 'Invalid email or password.'
      render :new
    end
  end

  def destroy
    session[:franchise_id] = nil
    flash[:notice] = 'Logged out successfully.'
    redirect_to franchise_login_path
  end

  private

  def current_franchise
    @current_franchise ||= Franchise.find(session[:franchise_id]) if session[:franchise_id]
  end
  helper_method :current_franchise

  def franchise_logged_in?
    !!current_franchise
  end
  helper_method :franchise_logged_in?
end