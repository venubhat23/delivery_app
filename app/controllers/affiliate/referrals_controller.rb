class Affiliate::ReferralsController < ApplicationController
  layout 'affiliate'
  skip_before_action :require_login
  before_action :authenticate_affiliate!
  before_action :set_referral, only: [:show, :edit, :update, :destroy]

  def index
    @referrals = current_affiliate.referrals.order(created_at: :desc).limit(20)
    @total_referrals = current_affiliate.total_referrals
    @pending_referrals = current_affiliate.pending_referrals
    @approved_referrals = current_affiliate.approved_referrals
    @total_earnings = current_affiliate.total_earnings || 0
  end

  def show
  end

  def new
    @referral = current_affiliate.referrals.build
    # Set default reward amount from application settings
    @referral.reward_amount = get_default_referral_reward
  end

  def create
    @referral = current_affiliate.referrals.build(referral_params)
    @referral.reward_amount = get_default_referral_reward

    if @referral.save
      redirect_to affiliate_referral_path(@referral), notice: 'Customer referral was successfully submitted!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @referral.pending? && @referral.update(referral_params)
      redirect_to affiliate_referral_path(@referral), notice: 'Referral was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @referral.pending?
      @referral.destroy
      redirect_to affiliate_referrals_path, notice: 'Referral was successfully deleted.'
    else
      redirect_to affiliate_referral_path(@referral), alert: 'Cannot delete approved or rejected referrals.'
    end
  end

  private

  def set_referral
    @referral = current_affiliate.referrals.find(params[:id])
  end

  def referral_params
    params.require(:referral).permit(:customer_name, :customer_phone, :customer_email, :notes)
  end

  def get_default_referral_reward
    # Default reward amount - you can make this configurable
    500.0
  end

  def authenticate_affiliate!
    unless current_affiliate
      redirect_to affiliate_login_path, alert: 'Please log in to access referrals.'
    end
  end

end