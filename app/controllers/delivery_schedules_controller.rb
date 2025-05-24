class DeliverySchedulesController < ApplicationController
  before_action :require_login
  before_action :set_delivery_schedule, only: [:show, :edit, :update, :destroy, :generate_assignments, :cancel_schedule]

  def index
    @delivery_schedules = DeliverySchedule.includes(:customer, :user, :product).order(created_at: :desc)
    @total_schedules = @delivery_schedules.count
    @active_schedules = @delivery_schedules.active.count
    @completed_schedules = @delivery_schedules.completed.count
  end

  def show
    @assignments = @delivery_schedule.delivery_assignments.includes(:product).order(:scheduled_date)
    @assignments_by_status = @assignments.group(:status).count
  end

  def new
    @delivery_schedule = DeliverySchedule.new
    @customers = Customer.includes(:delivery_person)
    @products = Product.all
    
    # Set default dates
    @delivery_schedule.start_date = Date.current
    @delivery_schedule.end_date = Date.current + 1.month
  end

  def create
    @delivery_schedule = DeliverySchedule.new(delivery_schedule_params)
    @delivery_schedule.user = current_user
    @delivery_schedule.status = 'active'

    if @delivery_schedule.save
      # Generate assignments in background or immediately
      GenerateScheduleAssignmentsJob.perform_later(@delivery_schedule.id)
      
      redirect_to @delivery_schedule, notice: 'Delivery schedule was successfully created. Assignments are being generated...'
    else
      @customers = Customer.includes(:delivery_person)
      @products = Product.all
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @customers = Customer.includes(:delivery_person)
    @products = Product.all
  end

  def update
    old_params = {
      start_date: @delivery_schedule.start_date,
      end_date: @delivery_schedule.end_date,
      frequency: @delivery_schedule.frequency
    }

    if @delivery_schedule.update(delivery_schedule_params)
      # Regenerate assignments if dates or frequency changed
      if schedule_changed?(old_params)
        RegenerateAssignmentsJob.perform_later(@delivery_schedule.id)
        notice_message = 'Schedule updated successfully. Assignments are being regenerated...'
      else
        notice_message = 'Schedule updated successfully.'
      end
      
      redirect_to @delivery_schedule, notice: notice_message
    else
      @customers = Customer.includes(:delivery_person)
      @products = Product.all
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @delivery_schedule.destroy
    redirect_to delivery_schedules_url, notice: 'Delivery schedule was successfully deleted.'
  end

  def generate_assignments
    if @delivery_schedule.generate_assignments!
      redirect_to @delivery_schedule, notice: 'Assignments generated successfully.'
    else
      redirect_to @delivery_schedule, alert: 'Failed to generate assignments.'
    end
  end

  def cancel_schedule
    @delivery_schedule.cancel!
    redirect_to @delivery_schedule, notice: 'Schedule has been cancelled and all pending assignments have been cancelled.'
  end

  # API endpoint for creating bulk schedules
  def create_bulk
    results = { success: 0, errors: [] }
    
    params[:schedules].each do |schedule_params|
      schedule = DeliverySchedule.new(schedule_params.permit(:customer_id, :product_id, :start_date, :end_date, :frequency))
      schedule.user = current_user
      schedule.status = 'active'
      
      if schedule.save
        GenerateScheduleAssignmentsJob.perform_later(schedule.id)
        results[:success] += 1
      else
        results[:errors] << { customer_id: schedule_params[:customer_id], errors: schedule.errors.full_messages }
      end
    end

    render json: results
  end

  private

  def set_delivery_schedule
    @delivery_schedule = DeliverySchedule.find(params[:id])
  end

  def delivery_schedule_params
    params.require(:delivery_schedule).permit(:customer_id, :product_id, :frequency, :start_date, :end_date, :default_quantity, :default_unit)
  end

  def schedule_changed?(old_params)
    old_params[:start_date] != @delivery_schedule.start_date ||
    old_params[:end_date] != @delivery_schedule.end_date ||
    old_params[:frequency] != @delivery_schedule.frequency
  end
end