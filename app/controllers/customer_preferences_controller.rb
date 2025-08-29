class CustomerPreferencesController < ApplicationController
  before_action :require_login
  before_action :set_customer_preference, only: [:show, :edit, :update, :destroy]

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
    @customer = @customer_preference.customer
  end

  def create
    @customer_preference = CustomerPreference.new(customer_preference_params)

    if @customer_preference.save
      @customer_preference.generate_referral_code if @customer_preference.referral_enabled?
      redirect_to customer_path(@customer_preference.customer), notice: 'Customer preferences were successfully created.'
    else
      if params[:customer_preference][:customer_id].present?
        @customer = Customer.find(params[:customer_preference][:customer_id])
        render :new_for_customer
      else
        @customers = Customer.active.order(:name)
        render :new
      end
    end
  end

  def update
    if @customer_preference.update(customer_preference_params)
      @customer_preference.generate_referral_code if @customer_preference.referral_enabled? && @customer_preference.referral_code.blank?
      redirect_to customer_path(@customer_preference.customer), notice: 'Customer preferences were successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @customer_preference.destroy
    redirect_to customer_preferences_path, notice: 'Customer preference was successfully deleted.'
  end

  def edit_for_customer
    @customer = Customer.find(params[:id])
    @customer_preference = @customer.customer_preference
    
    if @customer_preference
      render :edit
    else
      redirect_to preferences_new_customer_path(@customer)
    end
  end

  def new_for_customer
    @customer = Customer.find(params[:id])
    @customer_preference = @customer.build_customer_preference
    render :new_for_customer
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
      :skip_weekends, :special_instructions, :referral_enabled,
      :address_request_notes, notification_preferences: {}
    )
  end
end