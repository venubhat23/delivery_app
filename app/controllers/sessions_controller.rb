class SessionsController < ApplicationController
  skip_before_action :require_login, only: [:new, :create]
  layout false, only: [:new]

  def new
  end
  
  def create
    # First try to find a regular user
    user = User.find_by(email: params[:email])

    if user && user.authenticate(params[:password])
      session[:user_id] = user.id
      session[:franchise_id] = nil # Clear any franchise session
      flash[:notice] = "Welcome back, #{user.name}!"
      redirect_to root_path
    else
      # If user login failed, try franchise login
      franchise = Franchise.find_by(email: params[:email])

      if franchise && franchise.authenticate(params[:password])
        if franchise.active?
          session[:franchise_id] = franchise.id
          session[:user_id] = nil # Clear any user session
          flash[:notice] = "Welcome back, #{franchise.name}!"
          redirect_to root_path
        else
          flash.now[:alert] = 'Your franchise account is inactive. Please contact admin.'
          render :new
        end
      else
        flash.now[:alert] = 'Invalid email or password.'
        render :new
      end
    end
  end
  
  def destroy
    session[:user_id] = nil
    session[:franchise_id] = nil
    flash[:notice] = 'Logged out successfully.'
    redirect_to login_path
  end
end
