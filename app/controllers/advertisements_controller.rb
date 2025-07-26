class AdvertisementsController < ApplicationController
  before_action :require_login
  before_action :set_advertisement, only: [:show, :edit, :update, :destroy]

  def index
    @advertisements = Advertisement.includes(:user).by_user(current_user).order(created_at: :desc)
    @advertisements = @advertisements.where(status: params[:status]) if params[:status].present?
    @total_advertisements = @advertisements.count
    
    # Filter by status for stats
    @active_count = Advertisement.by_user(current_user).active.count
    @inactive_count = Advertisement.by_user(current_user).inactive.count
    @current_count = Advertisement.by_user(current_user).current.count
  end

  def show
  end

  def new
    @advertisement = Advertisement.new
  end

  def create
    @advertisement = Advertisement.new(advertisement_params)
    @advertisement.user = current_user
    
    if @advertisement.save
      redirect_to @advertisement, notice: 'Advertisement was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @advertisement.update(advertisement_params)
      redirect_to @advertisement, notice: 'Advertisement was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @advertisement.destroy
    redirect_to advertisements_url, notice: 'Advertisement was successfully deleted.'
  end

  private

  def set_advertisement
    @advertisement = Advertisement.find(params[:id])
  end

  def advertisement_params
    params.require(:advertisement).permit(:name, :image_url, :start_date, :end_date, :status)
  end
end