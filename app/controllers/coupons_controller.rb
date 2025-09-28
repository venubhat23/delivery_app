class CouponsController < ApplicationController
  before_action :require_login
  before_action :set_coupon, only: [:show, :edit, :update, :destroy]

  def index
    @coupons = Coupon.all.order(created_at: :desc)
    @coupons = @coupons.where(status: params[:status]) if params[:status].present?
    @coupons = @coupons.where("code ILIKE ? OR description ILIKE ?", "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?

    @total_coupons = @coupons.count
    @active_coupons = Coupon.active.count
    @expired_coupons = Coupon.expired.count
    @total_coupon_value = @coupons.sum(:amount)
  end

  def show
  end

  def new
    @coupon = Coupon.new
  end

  def create
    @coupon = Coupon.new(coupon_params)

    if @coupon.save
      redirect_to coupon_path(@coupon), notice: 'Coupon was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @coupon.update(coupon_params)
      redirect_to coupon_path(@coupon), notice: 'Coupon was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @coupon.destroy
    redirect_to coupons_url, notice: 'Coupon was successfully deleted.'
  end

  private

  def set_coupon
    @coupon = Coupon.find(params[:id])
  end

  def coupon_params
    params.require(:coupon).permit(:code, :amount, :description, :expires_at, :status)
  end
end
