class Api::V1::AuthenticationController < ApplicationController
  skip_before_action :authenticate_user!, only: [:login, :register]
  
  def login
    user = User.find_by(email: params[:email])
    
    if user&.authenticate(params[:password])
      token = jwt_encode(user_id: user.id)
      render json: {
        message: 'Login successful',
        token: token,
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          role: user.role
        }
      }, status: 200
    else
      render json: { error: 'Invalid email or password' }, status: 401
    end
  end
  
  def register
    user = User.new(user_params)
    
    if user.save
      token = jwt_encode(user_id: user.id)
      render json: {
        message: 'Registration successful',
        token: token,
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          role: user.role
        }
      }, status: 201
    else
      render json: { errors: user.errors.full_messages }, status: 422
    end
  end
  
  def logout
    # In a stateless JWT system, logout is typically handled client-side
    # by removing the token from storage
    render json: { message: 'Logged out successfully' }, status: 200
  end
  
  private
  
  def user_params
    params.permit(:name, :email, :password, :password_confirmation, :phone, :role)
  end
end