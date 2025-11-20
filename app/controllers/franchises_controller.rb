class FranchisesController < ApplicationController
  before_action :set_franchise, only: [:show, :edit, :update, :destroy, :reset_password, :toggle_status]

  def index
    @franchises = Franchise.all.order(:name)
    @total_franchises = @franchises.count
    @total_bookings = FranchiseBooking.count
    @total_revenue = FranchiseBooking.sum(:price)
    @active_franchises = @franchises.active.count
  end

  def show
    @franchise_bookings = @franchise.franchise_bookings.recent.limit(10)
  end

  def new
    @franchise = Franchise.new
  end

  def create
    @franchise = Franchise.new(franchise_params)

    if @franchise.save
      redirect_to franchises_path, notice: 'Franchise was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @franchise.update(franchise_params)
      redirect_to franchise_path(@franchise), notice: 'Franchise was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @franchise.destroy
    redirect_to franchises_path, notice: 'Franchise was successfully deleted.'
  end

  def reset_password
    new_password = SecureRandom.alphanumeric(8)
    @franchise.update(password: new_password)

    # Here you would typically send an email with the new password
    flash[:notice] = "Password reset successfully. New password: #{new_password}"
    redirect_to franchise_path(@franchise)
  end

  def toggle_status
    @franchise.update(active: !@franchise.active)
    status = @franchise.active? ? 'activated' : 'deactivated'
    redirect_to franchise_path(@franchise), notice: "Franchise #{status} successfully."
  end

  private

  def set_franchise
    @franchise = Franchise.find(params[:id])
  end

  def franchise_params
    params.require(:franchise).permit(:name, :email, :phone, :password, :location, :gst_number, :active)
  end
end
