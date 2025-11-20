class Franchise::FranchiseBookingsController < Franchise::BaseController
  before_action :set_booking, only: [:show, :edit, :update, :destroy]

  def index
    @bookings = current_franchise.franchise_bookings
                                .includes(:product)
                                .order(created_at: :desc)
                                .page(params[:page])
                                .per(20)

    @total_bookings = current_franchise.total_bookings
    @total_amount = current_franchise.total_bookings_amount
    @pending_count = current_franchise.pending_bookings.count
    @completed_count = current_franchise.completed_bookings.count
  end

  def show
  end

  def new
    @booking = current_franchise.franchise_bookings.build
    @products = Product.all.order(:name)
  end

  def create
    @booking = current_franchise.franchise_bookings.build(booking_params)
    @booking.booking_date = Date.current
    @booking.status = 'pending'

    if @booking.save
      # Auto-create delivery assignment for the booking
      create_delivery_assignment(@booking)

      flash[:success] = 'Booking created successfully!'
      redirect_to franchise_bookings_path
    else
      @products = Product.all.order(:name)
      flash.now[:error] = 'Please fix the errors below.'
      render :new
    end
  end

  def edit
    @products = Product.all.order(:name)
  end

  def update
    if @booking.update(booking_params)
      flash[:success] = 'Booking updated successfully!'
      redirect_to franchise_booking_path(@booking)
    else
      @products = Product.all.order(:name)
      flash.now[:error] = 'Please fix the errors below.'
      render :edit
    end
  end

  def destroy
    @booking.destroy
    flash[:success] = 'Booking deleted successfully!'
    redirect_to franchise_bookings_path
  end

  private

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