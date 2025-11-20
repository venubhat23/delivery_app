class Admin::AffiliatesController < ApplicationController
  before_action :require_login
  before_action :require_admin
  before_action :set_affiliate, only: [:show, :edit, :update, :destroy, :approve, :suspend]

  def index
    @affiliates = Affiliate.all.order(created_at: :desc)
    @pending_affiliates = @affiliates.select { |a| a.pending? rescue false }
    @approved_affiliates = @affiliates.select { |a| a.approved? rescue false }
    @total_earnings = @approved_affiliates.sum { |a| a.total_earnings || 0 }
    @total_referrals = Referral.count
  end

  def show
    @referrals = @affiliate.referrals.order(created_at: :desc).limit(10)
    @bookings = @affiliate.affiliate_bookings.limit(10)
    @monthly_referrals = {}
  end

  def new
    @affiliate = Affiliate.new
  end

  def create
    @affiliate = Affiliate.new(affiliate_params)
    @affiliate.status = 'approved'
    @affiliate.active = true

    if @affiliate.save
      redirect_to admin_affiliate_path(@affiliate), notice: 'Affiliate was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    affiliate_update_params = affiliate_params

    # Remove password params if password is blank (don't change password)
    if affiliate_update_params[:password].blank?
      affiliate_update_params = affiliate_update_params.except(:password, :password_confirmation)
    end

    if @affiliate.update(affiliate_update_params)
      redirect_to admin_affiliate_path(@affiliate), notice: 'Affiliate was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @affiliate.destroy
    redirect_to admin_affiliates_path, notice: 'Affiliate was successfully deleted.'
  end

  def approve
    @affiliate.update!(status: 'approved', active: true)
    redirect_to admin_affiliate_path(@affiliate), notice: 'Affiliate has been approved.'
  end

  def suspend
    @affiliate.update!(status: 'suspended', active: false)
    redirect_to admin_affiliate_path(@affiliate), notice: 'Affiliate has been suspended.'
  end

  private

  def set_affiliate
    @affiliate = Affiliate.find(params[:id])
  end

  def affiliate_params
    params.require(:affiliate).permit(:name, :email, :phone, :location, :commission_rate, :active, :password, :password_confirmation)
  end

end
