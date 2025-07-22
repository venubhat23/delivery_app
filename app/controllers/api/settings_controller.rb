class Api::SettingsController < ApplicationController
  before_action :require_login
  before_action :set_current_user

  # GET /api/settings/timezones
  # Get list of available timezones
  def available_timezones
    timezones = User.available_timezones.map do |tz|
      {
        value: tz,
        label: tz.gsub('_', ' '),
        offset: ActiveSupport::TimeZone[tz].formatted_offset
      }
    end

    render json: {
      success: true,
      data: {
        timezones: timezones,
        current_timezone: @current_user.timezone
      }
    }
  end

  # PUT /api/settings/timezone
  # Update user's timezone
  def update_timezone
    timezone = params[:timezone]
    
    unless User.available_timezones.include?(timezone)
      return render json: {
        success: false,
        error: 'Invalid timezone selected',
        available_timezones: User.available_timezones
      }, status: :unprocessable_entity
    end

    if @current_user.update(timezone: timezone)
      render json: {
        success: true,
        message: 'Timezone updated successfully',
        data: {
          timezone: @current_user.timezone,
          current_time: @current_user.current_time_in_timezone.strftime('%Y-%m-%d %H:%M:%S %Z')
        }
      }
    else
      render json: {
        success: false,
        error: 'Failed to update timezone',
        errors: @current_user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # GET /api/settings/timezone
  # Get current user's timezone
  def show_timezone
    render json: {
      success: true,
      data: {
        timezone: @current_user.timezone,
        timezone_label: @current_user.timezone.gsub('_', ' '),
        offset: @current_user.timezone_object.formatted_offset,
        current_time: @current_user.current_time_in_timezone.strftime('%Y-%m-%d %H:%M:%S %Z')
      }
    }
  end

  # DELETE /api/settings/account
  # Soft delete user account
  def delete_account
    password = params[:password]
    
    unless @current_user.authenticate(password)
      return render json: {
        success: false,
        error: 'Invalid password. Please enter your current password to delete your account.'
      }, status: :unauthorized
    end

    begin
      # Soft delete the user
      @current_user.soft_delete!
      
      # Clear the session
      session[:user_id] = nil
      
      render json: {
        success: true,
        message: 'Your account has been successfully deleted. We\'re sorry to see you go!'
      }
    rescue => e
      render json: {
        success: false,
        error: 'Failed to delete account. Please try again or contact support.',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # GET /api/settings/profile
  # Get current user profile for settings
  def show_profile
    render json: {
      success: true,
      data: {
        id: @current_user.id,
        name: @current_user.name,
        email: @current_user.email,
        phone: @current_user.phone,
        role: @current_user.role,
        timezone: @current_user.timezone,
        created_at: @current_user.created_at,
        updated_at: @current_user.updated_at
      }
    }
  end

  # PUT /api/settings/profile
  # Update user profile
  def update_profile
    allowed_params = profile_params
    
    if @current_user.update(allowed_params)
      render json: {
        success: true,
        message: 'Profile updated successfully',
        data: {
          id: @current_user.id,
          name: @current_user.name,
          email: @current_user.email,
          phone: @current_user.phone,
          timezone: @current_user.timezone
        }
      }
    else
      render json: {
        success: false,
        error: 'Failed to update profile',
        errors: @current_user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def set_current_user
    @current_user = User.find(session[:user_id])
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: 'User not found' }, status: :not_found
  end

  def profile_params
    params.require(:user).permit(:name, :phone, :timezone)
  end
end