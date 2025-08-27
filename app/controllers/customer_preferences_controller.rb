class CustomerPreferencesController < ApplicationController
  before_action :set_customer_preference, only: [:show, :edit, :update, :destroy]
  before_action :authenticate_user!

  def index
    @customer_preferences = CustomerPreference.includes(:customer).recent
    @customer_preferences = @customer_preferences.by_language(params[:language]) if params[:language].present?
    @customer_preferences = @customer_preferences.page(params[:page])
  end

  def show
  end

  def new
    @customer_preference = CustomerPreference.new
    @customers = Customer.active.order(:name)
  end

  def edit
  end

  def create
    @customer_preference = CustomerPreference.new(customer_preference_params)

    if @customer_preference.save
      redirect_to customer_preferences_path, notice: 'Customer preference was successfully created.'
    else
      @customers = Customer.active.order(:name)
      render :new
    end
  end

  def update
    if @customer_preference.update(customer_preference_params)
      redirect_to customer_preferences_path, notice: 'Customer preference was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @customer_preference.destroy
    redirect_to customer_preferences_path, notice: 'Customer preference was successfully deleted.'
  end

  def bulk_update_notifications
    preferences = params[:preferences] || {}
    success_count = 0
    
    preferences.each do |customer_id, prefs|
      customer_pref = CustomerPreference.find_by(customer_id: customer_id)
      if customer_pref&.update(notification_preferences: prefs)
        success_count += 1
      end
    end
    
    render json: { 
      success: true, 
      message: "#{success_count} preferences updated successfully" 
    }
  end

  private

  def set_customer_preference
    @customer_preference = CustomerPreference.find(params[:id])
  end

  def customer_preference_params
    params.require(:customer_preference).permit(
      :customer_id, :language, :delivery_time_start, :delivery_time_end,
      :skip_weekends, :special_instructions, :notification_preferences
    )
  end
end