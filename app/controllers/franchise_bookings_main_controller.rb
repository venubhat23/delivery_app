class FranchiseBookingsMainController < ApplicationController
  before_action :require_franchise_login
  before_action :set_booking, only: [:show, :edit, :update, :destroy]

  def index
    @bookings = current_franchise.franchise_bookings
                                .includes(:product)
                                .order(created_at: :desc)

    @total_bookings = current_franchise.total_bookings
    @total_amount = current_franchise.total_bookings_amount
    @pending_count = current_franchise.pending_bookings.count
    @completed_count = current_franchise.completed_bookings.count
  end

  def show
  end

  def new
    @booking = current_franchise.franchise_bookings.build
    @products = Product.active.order(:name)
  end

  def create
    # Handle JSON request from cart
    if request.format.json?
      return create_from_cart
    end

    # Handle single booking from form
    @booking = current_franchise.franchise_bookings.build(booking_params)
    @booking.booking_date = Date.current
    @booking.status = 'pending'

    if @booking.save
      # Auto-create delivery assignment for the booking
      create_delivery_assignment(@booking)

      flash[:success] = 'Booking created successfully!'
      redirect_to franchise_bookings_main_index_path
    else
      @products = Product.active.order(:name)
      flash.now[:error] = 'Please fix the errors below.'
      render :new
    end
  end

  def edit
    @products = Product.active.order(:name)
  end

  def update
    if @booking.update(booking_params)
      flash[:success] = 'Booking updated successfully!'
      redirect_to franchise_bookings_main_path(@booking)
    else
      @products = Product.active.order(:name)
      flash.now[:error] = 'Please fix the errors below.'
      render :edit
    end
  end

  def destroy
    @booking.destroy
    flash[:success] = 'Booking deleted successfully!'
    redirect_to franchise_bookings_main_index_path
  end

  private

  def create_from_cart
    bookings_params = params[:bookings]

    created_bookings = []
    errors = []

    ActiveRecord::Base.transaction do
      bookings_params.each do |booking_data|
        booking = current_franchise.franchise_bookings.build(
          product_id: booking_data[:product_id],
          quantity: booking_data[:quantity],
          price: booking_data[:price],
          notes: booking_data[:notes],
          booking_date: Date.current,
          status: 'pending'
        )

        if booking.save
          # Auto-create delivery assignment
          create_delivery_assignment(booking)
          created_bookings << booking
        else
          errors << "#{booking.product&.name}: #{booking.errors.full_messages.join(', ')}"
        end
      end

      if errors.any?
        raise ActiveRecord::Rollback
      end
    end

    if errors.any?
      render json: { success: false, errors: errors }
    else
      render json: { success: true, message: "#{created_bookings.count} bookings created successfully!" }
    end
  end

  def require_franchise_login
    unless current_franchise
      flash[:alert] = 'Access denied. This section is for franchise users only.'
      redirect_to login_path
    end
  end

  def set_booking
    @booking = current_franchise.franchise_bookings.find(params[:id])
  end

  def booking_params
    params.require(:franchise_booking).permit(:product_id, :quantity, :price, :notes)
  end

  def create_delivery_assignment(booking)
    DeliveryAssignment.create!(
      franchise: current_franchise,
      product: booking.product,
      quantity: booking.quantity,
      scheduled_date: booking.booking_date,
      unit: booking.product.unit_type,
      status: 'pending',
      notes: "Auto-created from franchise booking ##{booking.id}"
    )
  rescue => e
    Rails.logger.error "Failed to create delivery assignment for booking #{booking.id}: #{e.message}"
  end
end