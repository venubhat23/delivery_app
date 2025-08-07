class DeliveryAssignmentsController < ApplicationController
  before_action :require_login
  before_action :set_delivery_assignment, only: [:show, :edit, :update, :destroy, :complete, :cancel]

  def index
    # Date filtering - default to today, but allow viewing other dates
    # Fix date filter to show exact date matches only
    if params[:date].present?
      begin
        filter_date = Date.parse(params[:date])
      rescue ArgumentError
        filter_date = Date.today
      end
    else
      filter_date = Date.today
    end
    
    # Optimize queries with proper includes to prevent N+1 queries
    @delivery_assignments = DeliveryAssignment.includes(
      :user, 
      :delivery_person, 
      :product, 
      :customer, 
      :delivery_schedule,
      :invoice
    ).where(scheduled_date: filter_date)
     .order(created_at: :desc)
    
    # Filter by status if provided
    if params[:status].present?
      @delivery_assignments = @delivery_assignments.where(status: params[:status])
    end
    
    # Filter by delivery person if provided
    if params[:delivery_person_id].present?
      @delivery_assignments = @delivery_assignments.joins(:delivery_person)
                                            .where(delivery_person: { id: params[:delivery_person_id] })
    end

    # Search by customer name
    if params[:search].present?
      @delivery_assignments = @delivery_assignments.search_by_customer(params[:search])
    end

    # Add pagination - 50 assignments per page
    @total_assignments = @delivery_assignments.count
    @delivery_assignments = @delivery_assignments.page(params[:page]).per(50)

    @delivery_people = User.delivery_people.all
    @statuses = DeliveryAssignment.distinct.pluck(:status).compact
    @current_date = filter_date
  end

  def show
  end

  def new
    @delivery_assignment = DeliveryAssignment.new
    @customers = Customer.all
    @delivery_people = User.delivery_people.all
    @products = Product.all
  end

  def create
    # Check if this is a scheduled delivery (date range)
    if delivery_assignment_params[:start_date].present? && delivery_assignment_params[:end_date].present?
      create_scheduled_deliveries
    else
      create_single_delivery
    end
  end

  def edit
    @customers = Customer.all
    @delivery_people = User.delivery_people.all
    @products = Product.all
  end

  def update
    if @delivery_assignment.update(delivery_assignment_params)
      redirect_to @delivery_assignment, notice: 'Delivery assignment was successfully updated.'
    else
      @customers = Customer.all
      @delivery_people = User.delivery_people.all
      @products = Product.all
      render :edit
    end
  end

  def destroy
    @delivery_assignment.destroy
    respond_to do |format|
      format.html { redirect_to delivery_assignments_path, notice: 'Delivery assignment was successfully deleted.' }
      format.json { head :no_content }
    end
  rescue => e
    respond_to do |format|
      format.html { redirect_to delivery_assignments_path, alert: 'Failed to delete delivery assignment.' }
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end

  def complete
    @delivery_assignment.status = 'completed'
    @delivery_assignment.completed_at = Time.current
    
    if @delivery_assignment.save
      create_invoice_for_delivery
      respond_to do |format|
        format.html { redirect_to delivery_assignments_path, notice: 'Delivery marked as completed successfully!' }
        format.json { render :show, status: :ok, location: @delivery_assignment }
      end
    else
      respond_to do |format|
        format.html { redirect_to delivery_assignments_path, alert: 'Failed to complete delivery.' }
        format.json { render json: @delivery_assignment.errors, status: :unprocessable_entity }
      end
    end
  end

  def cancel
    if @delivery_assignment.update(status: 'cancelled', cancelled_at: Time.current)
      redirect_to @delivery_assignment, notice: 'Delivery assignment cancelled.'
    else
      redirect_to @delivery_assignment, alert: 'Failed to cancel delivery assignment.'
    end
  end

  def bulk_complete
    pending_assignments = DeliveryAssignment.where(status: 'pending')
    
    # Apply filters if they exist
    if params[:delivery_person_id].present?
      pending_assignments = pending_assignments.where(user_id: params[:delivery_person_id])
    end
    
    # Only complete assignments for today or past dates to avoid completing future assignments
    pending_assignments = pending_assignments.where('scheduled_date <= ?', Date.current)
    
    completed_count = 0
    failed_count = 0
    
    pending_assignments.find_each do |assignment|
      if assignment.update(status: 'completed', completed_at: Time.current)
        create_invoice_for_assignment(assignment)
        completed_count += 1
      else
        failed_count += 1
      end
    end
    
    if completed_count > 0
      message = "Successfully completed #{completed_count} delivery assignment(s)."
      message += " #{failed_count} failed to update." if failed_count > 0
      redirect_to delivery_assignments_path, notice: message
    else
      redirect_to delivery_assignments_path, alert: 'No pending assignments found to complete.'
    end
  end

  private

  def set_delivery_assignment
    @delivery_assignment = DeliveryAssignment.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to delivery_assignments_path, alert: 'Delivery assignment not found.'
  end

  def delivery_assignment_params
    da_params = params.require(:delivery_assignment).permit(
      :customer_id, :product_id, :quantity, :unit,
      :delivery_date, :special_instructions, :status, :priority,
      :delivery_person_id, :start_date, :end_date, :frequency
    ).dup  # Create a copy to avoid modifying original params

    # Handle delivery_person_id to user_id mapping
    if da_params[:delivery_person_id].present?
      da_params[:user_id] = da_params[:delivery_person_id]
    end

    # Convert delivery_date to scheduled_date since delivery_date is just an alias method
    if da_params[:delivery_date].present?
      da_params[:scheduled_date] = da_params[:delivery_date]
      da_params.delete(:delivery_date)
    end

    # Set default unit if not provided
    da_params[:unit] = 'pieces' if da_params[:unit].blank?

    da_params
  end

  def create_single_delivery
    @delivery_assignment = DeliveryAssignment.new(delivery_assignment_params.except(:start_date, :end_date, :frequency))
    @delivery_assignment.status = 'pending' if @delivery_assignment.status.blank?

    if @delivery_assignment.save
      redirect_to delivery_assignments_path, notice: 'Delivery assignment was successfully created.'
    else
      load_form_data
      render :new
    end
  end

  def create_scheduled_deliveries
    start_date = Date.parse(delivery_assignment_params[:start_date])
    end_date = Date.parse(delivery_assignment_params[:end_date])
    frequency = delivery_assignment_params[:frequency] || 'daily'
    
    # First create the delivery schedule
    delivery_schedule = DeliverySchedule.new(
      customer_id: delivery_assignment_params[:customer_id],
      user_id: delivery_assignment_params[:delivery_person_id],
      product_id: delivery_assignment_params[:product_id],
      start_date: start_date,
      end_date: end_date,
      frequency: frequency,
      status: 'active',
      default_quantity: delivery_assignment_params[:quantity] || 1,
      default_unit: 'pieces'
    )

    if delivery_schedule.save
      # Generate delivery assignments based on frequency
      created_count = generate_delivery_assignments(delivery_schedule)
      
      redirect_to delivery_assignments_path, 
                  notice: "Delivery schedule created successfully. #{created_count} delivery assignments generated."
    else
      @delivery_assignment = DeliveryAssignment.new(delivery_assignment_params.except(:start_date, :end_date, :frequency))
      @delivery_assignment.errors.add(:base, "Failed to create delivery schedule: #{delivery_schedule.errors.full_messages.join(', ')}")
      load_form_data
      render :new
    end
  end

  def generate_delivery_assignments(delivery_schedule)
    current_date = delivery_schedule.start_date
    created_count = 0
    
    while current_date <= delivery_schedule.end_date
      # Create delivery assignment for current date
      assignment = DeliveryAssignment.new(
        customer_id: delivery_schedule.customer_id,
        user_id: delivery_schedule.user_id,
        product_id: delivery_schedule.product_id,
        quantity: delivery_schedule.default_quantity,
        scheduled_date: current_date,
        status: 'pending',
        unit: delivery_schedule.product.unit_type,
        delivery_schedule_id: delivery_schedule.id
      )
      if assignment.save
        created_count += 1
      end
      
      # Move to next date based on frequency
      current_date = next_delivery_date(current_date, delivery_schedule.frequency)
    end
    
    created_count
  end

  def next_delivery_date(current_date, frequency)
    case frequency
    when 'daily'
      current_date + 1.day
    when 'weekly'
      current_date + 1.week
    when 'monthly'
      current_date + 1.month
    when 'bi_weekly'
      current_date + 2.weeks
    else
      current_date + 1.day # default to daily
    end
  end

  def load_form_data
    @customers = Customer.all
    @delivery_people = User.delivery_people.all
    @products = Product.all
  end

  def create_invoice_for_delivery
    return if @delivery_assignment.invoice.present?
    
    begin
      invoice = Invoice.create!(
        customer: @delivery_assignment.customer,
        delivery_assignment: @delivery_assignment,
        amount: calculate_delivery_amount,
        due_date: 30.days.from_now,
        status: 'pending'
      )
      
      @delivery_assignment.update(invoice: invoice)
    rescue => e
      Rails.logger.error "Failed to create invoice: #{e.message}"
    end
  end

  def create_invoice_for_assignment(assignment)
    return if assignment.invoice.present?
    
    begin
      invoice = Invoice.create!(
        customer: assignment.customer,
        delivery_assignment: assignment,
        amount: (assignment.product&.price || 0) * (assignment.quantity || 1),
        due_date: 30.days.from_now,
        status: 'pending'
      )
      
      assignment.update(invoice: invoice)
    rescue => e
      Rails.logger.error "Failed to create invoice for assignment #{assignment.id}: #{e.message}"
    end
  end

  def calculate_delivery_amount
    # Basic calculation - you can customize this logic
    base_amount = @delivery_assignment.product&.price || 0
    quantity = @delivery_assignment.quantity || 1
    base_amount * quantity
  end
end