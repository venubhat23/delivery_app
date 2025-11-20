class Affiliate::BookingsController < ApplicationController
  layout 'affiliate'
  skip_before_action :require_login
  before_action :authenticate_affiliate!
  before_action :set_booking, only: [:show, :edit, :update, :destroy, :cancel]

  def index
    @bookings = current_affiliate.affiliate_bookings
                                 .includes(:product)
                                 .order(created_at: :desc)
                                 .limit(20)

    @total_bookings = current_affiliate.affiliate_bookings.count
    @pending_bookings = current_affiliate.affiliate_bookings.select { |b| b.pending? rescue false }.count
    @confirmed_bookings = current_affiliate.affiliate_bookings.select { |b| b.confirmed? rescue false }.count
    @completed_bookings = current_affiliate.affiliate_bookings.select { |b| b.completed? rescue false }.count
  end

  def show
  end

  def new
    @booking = current_affiliate.affiliate_bookings.build
    @products = Product.active.order(:name)
  end

  def create
    @booking = current_affiliate.affiliate_bookings.build(booking_params)

    if @booking.save
      redirect_to affiliate_booking_path(@booking), notice: 'Booking was successfully created.'
    else
      @products = Product.active.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @products = Product.active.order(:name)
  end

  def update
    if @booking.update(booking_params)
      redirect_to affiliate_booking_path(@booking), notice: 'Booking was successfully updated.'
    else
      @products = Product.active.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @booking.destroy
    redirect_to affiliate_bookings_path, notice: 'Booking was successfully deleted.'
  end

  def cancel
    reason = params[:reason] || 'Cancelled by affiliate'
    @booking.cancel!(reason)
    redirect_to affiliate_booking_path(@booking), notice: 'Booking has been cancelled.'
  end

  private

  def set_booking
    @booking = current_affiliate.affiliate_bookings.find(params[:id])
  end

  def booking_params
    params.require(:affiliate_booking).permit(:product_id, :quantity, :price, :booking_date, :notes)
  end

  def authenticate_affiliate!
    unless current_affiliate
      redirect_to affiliate_login_path, alert: 'Please log in to access bookings.'
    end
  end

end