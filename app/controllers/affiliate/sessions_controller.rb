class Affiliate::SessionsController < ApplicationController
  layout 'affiliate'
  skip_before_action :require_login

  def new
  end

  def create
    @affiliate = Affiliate.find_by(email: params[:email])

    if @affiliate&.authenticate(params[:password])
      if @affiliate.active?
        session[:affiliate_id] = @affiliate.id
        redirect_to affiliate_dashboard_path, notice: 'Welcome back!'
      else
        redirect_to affiliate_login_path, alert: 'Your account is not active. Please contact admin.'
      end
    else
      flash.now[:alert] = 'Invalid email or password'
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session[:affiliate_id] = nil
    redirect_to affiliate_login_path, notice: 'You have been logged out successfully.'
  end
end