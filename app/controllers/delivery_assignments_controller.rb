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
    
    # Convert date to string format for database comparison if needed
    filter_date_str = filter_date.to_s
    
    # Optimize queries with proper includes to prevent N+1 queries
    @delivery_assignments = DeliveryAssignment.includes(
      :user, 
      :delivery_person, 
      :product, 
      :customer, 
      :delivery_schedule,
      :invoice
    ).where("DATE(scheduled_date) = ?", filter_date_str)
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

    if params[:customer_id].present?
      @delivery_assignments = @delivery_assignments.where(customer_id: params[:customer_id])
    end

    # Store filtered assignments for statistics before pagination
    @filtered_assignments = @delivery_assignments
    
    # Calculate statistics for all filtered assignments (not just current page)
    @total_assignments = @filtered_assignments.count
    @pending_assignments = @filtered_assignments.where(status: 'pending').count
    @completed_assignments = @filtered_assignments.where(status: 'completed').count
    @overdue_assignments = @filtered_assignments.where(status: 'pending').where('scheduled_date < ?', Date.current).count
    @completion_rate = @total_assignments > 0 ? ((@completed_assignments.to_f / @total_assignments) * 100).round(1) : 0

    # Add pagination - 50 assignments per page
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
    create_single_delivery
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

  # AJAX action for search suggestions
  def search_suggestions
    query = params[:q].to_s.strip
    page = (params[:page] || 1).to_i
    per_page = 15
    offset = (page - 1) * per_page
    
    if query.present? && query.length >= 1
      # Get customers matching name or phone/alt_phone starting with/containing digits
      customers = Customer.where(
                    "name ILIKE :name_q OR phone_number ILIKE :num_q OR alt_phone_number ILIKE :num_q",
                    name_q: "#{query}%",
                    num_q: "%#{query}%"
                  )
                  .limit(per_page)
                  .offset(offset)
                  .order(:name)
      
      # Get total count for pagination info
      total_customers = Customer.where(
                         "name ILIKE :name_q OR phone_number ILIKE :num_q OR alt_phone_number ILIKE :num_q",
                         name_q: "#{query}%",
                         num_q: "%#{query}%"
                       ).count
    else
      # When no query, return all customers (paginated)
      customers = Customer.limit(per_page).offset(offset).order(:name)
      total_customers = Customer.count
    end
    
    suggestions = []
    
    customers.each do |customer|
      suggestions << {
        type: 'customer',
        label: customer.name,
        value: customer.name,
        phone: customer.phone_number.presence || customer.alt_phone_number,
        id: customer.id
      }
    end
    
    has_more = (offset + customers.length) < total_customers
    
    render json: { 
      suggestions: suggestions,
      page: page,
      has_more: has_more,
      total_count: total_customers
    }
  end

  def bulk_complete
    # Handle different completion types
    case params[:complete_type]
    when 'all_today'
      # Complete all pending assignments for today (regardless of filters)
      pending_assignments = DeliveryAssignment
        .where(status: 'pending')
        .where('scheduled_date <= ?', Date.current)
        
    when 'filtered'
      # Complete specific assignment IDs (from filtered/paginated results)
      if params[:assignment_ids].present?
        assignment_ids = Array(params[:assignment_ids]).map(&:to_i).uniq
        pending_assignments = DeliveryAssignment
          .where(id: assignment_ids)
          .where(status: 'pending')
          .where('scheduled_date <= ?', Date.current)
      else
        # Fallback to no assignments if no IDs provided
        pending_assignments = DeliveryAssignment.none
      end
        
    else
      # Legacy support for existing complete_type values
      if params[:assignment_ids].present?
        assignment_ids = Array(params[:assignment_ids]).map(&:to_i).uniq
        pending_assignments = DeliveryAssignment
          .where(id: assignment_ids)
          .where(status: 'pending')
          .where('scheduled_date <= ?', Date.current)
      else
        # Start with pending assignments
        pending_assignments = DeliveryAssignment.where(status: 'pending')

        # Apply date filter (default to current date as set in index method)
        filter_date = Date.current
        if params[:date].present?
          begin
            filter_date = Date.parse(params[:date])
          rescue ArgumentError
            filter_date = Date.current
          end
        end
        pending_assignments = pending_assignments.where(scheduled_date: filter_date)

        # Apply other filters if they exist
        if params[:delivery_person_id].present?
          pending_assignments = pending_assignments.where(user_id: params[:delivery_person_id])
        end

        if params[:search].present?
          pending_assignments = pending_assignments.search_by_customer(params[:search])
        end

        # Determine completion scope based on complete_type parameter
        if params[:complete_type] == 'all'
          # Complete all filtered assignments (across all pages)
          # Only complete assignments for today or past dates to avoid completing future assignments
          pending_assignments = pending_assignments.where('scheduled_date <= ?', Date.current)
        else
          # Complete only current page assignments (default behavior)
          # Only complete assignments for today or past dates to avoid completing future assignments
          pending_assignments = pending_assignments.where('scheduled_date <= ?', Date.current)

          # Get current page assignments only
          page = params[:page] || 1
          pending_assignments = pending_assignments.page(page).per(50)
        end
      end
    end
    
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
      redirect_to delivery_assignments_path(params.permit(:date, :status, :delivery_person_id, :search)), notice: message
    else
      redirect_to delivery_assignments_path(params.permit(:date, :status, :delivery_person_id, :search)), alert: 'No pending assignments found to complete.'
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
      :scheduled_date, :special_instructions, :status, :priority,
      :delivery_person_id,
      additional_products: [:product_id, :quantity, :unit]
    ).dup  # Create a copy to avoid modifying original params

    # Handle delivery_person_id to user_id mapping
    if da_params[:delivery_person_id].present?
      da_params[:user_id] = da_params[:delivery_person_id]
    end

    # Set default unit if not provided
    da_params[:unit] = 'pieces' if da_params[:unit].blank?

    da_params
  end

  def create_single_delivery
    assignment_params = delivery_assignment_params.except(:additional_products)
    additional_products = delivery_assignment_params[:additional_products] || []
    
    # Create main delivery assignment
    @delivery_assignment = DeliveryAssignment.new(assignment_params)
    @delivery_assignment.status = 'pending' if @delivery_assignment.status.blank?

    if @delivery_assignment.save
      # Create additional product assignments
      created_count = 1 # Count the main assignment
      additional_products.each do |product_data|
        next if product_data[:product_id].blank?
        
        additional_assignment = DeliveryAssignment.new(
          customer_id: @delivery_assignment.customer_id,
          user_id: @delivery_assignment.user_id,
          product_id: product_data[:product_id],
          quantity: product_data[:quantity],
          unit: product_data[:unit] || 'pieces',
          scheduled_date: @delivery_assignment.scheduled_date,
          special_instructions: @delivery_assignment.special_instructions,
          status: 'pending'
        )
        
        if additional_assignment.save
          created_count += 1
        end
      end
      
      notice_message = created_count > 1 ? 
        "Successfully created #{created_count} delivery assignments." : 
        'Single delivery assignment was successfully created.'
        
      redirect_to delivery_assignments_path, notice: notice_message
    else
      load_form_data
      render :new
    end
  end

  def create_multi_product_deliveries
    customer_id = delivery_assignment_params[:customer_id]
    delivery_person_id = delivery_assignment_params[:delivery_person_id]
    start_date = delivery_assignment_params[:start_date].present? ? Date.parse(delivery_assignment_params[:start_date]) : nil
    end_date = delivery_assignment_params[:end_date].present? ? Date.parse(delivery_assignment_params[:end_date]) : nil
    frequency = delivery_assignment_params[:frequency] || 'daily'
    delivery_date = delivery_assignment_params[:delivery_date].present? ? Date.parse(delivery_assignment_params[:delivery_date]) : nil
    
    # Validate required fields
    if customer_id.blank? || delivery_person_id.blank?
      @delivery_assignment = DeliveryAssignment.new(delivery_assignment_params)
      @delivery_assignment.errors.add(:base, "Customer and delivery person are required.")
      load_form_data
      render :new
      return
    end
    
    # Check if it's scheduled (has date range) or single delivery
    is_scheduled = start_date.present? && end_date.present?
    is_single = delivery_date.present?
    
    if !is_scheduled && !is_single
      @delivery_assignment = DeliveryAssignment.new(delivery_assignment_params)
      @delivery_assignment.errors.add(:base, "Please provide either a delivery date or date range.")
      load_form_data
      render :new
      return
    end
    
    products_data = params[:assignment_products] || {}
    valid_products = products_data.select { |_, p| p[:product_id].present? && p[:quantity].present? }
    
    if valid_products.empty?
      @delivery_assignment = DeliveryAssignment.new(delivery_assignment_params)
      @delivery_assignment.errors.add(:base, "Please add at least one product.")
      load_form_data
      render :new
      return
    end
    
    begin
      schedules_created = 0
      assignments_created = 0
      
      ActiveRecord::Base.transaction do
        valid_products.each do |index, product_data|
          product = Product.find(product_data[:product_id])
          quantity = product_data[:quantity].to_f
          unit = product_data[:unit].presence || product.unit_type
          discount_amount = product_data[:discount_amount].to_f
          
          if is_scheduled
            # Create delivery schedule for this product
            delivery_schedule = DeliverySchedule.create!(
              customer_id: customer_id,
              user_id: delivery_person_id,
              product_id: product.id,
              start_date: start_date,
              end_date: end_date,
              frequency: frequency,
              status: 'active',
              default_quantity: quantity,
              default_unit: unit,
              default_discount_amount: discount_amount
            )
            
            schedules_created += 1
            
            # Generate delivery assignments based on schedule
            assignments_created += generate_delivery_assignments(delivery_schedule)
          else
            # Create single delivery assignment
            assignment = DeliveryAssignment.create!(
              customer_id: customer_id,
              user_id: delivery_person_id,
              product_id: product.id,
              quantity: quantity,
              unit: unit,
              scheduled_date: delivery_date,
              status: 'pending',
              special_instructions: delivery_assignment_params[:special_instructions],
              discount_amount: discount_amount
            )
            
            # Calculate and save final amount
            assignment.calculate_final_amount_after_discount
            
            assignments_created += 1
          end
        end
      end
      
      if is_scheduled
        redirect_to delivery_assignments_path, 
                    notice: "Successfully created #{schedules_created} delivery schedule(s) and #{assignments_created} delivery assignment(s)."
      else
        redirect_to delivery_assignments_path, 
                    notice: "Successfully created #{assignments_created} delivery assignment(s)."
      end
      
    rescue ActiveRecord::RecordInvalid => e
      @delivery_assignment = DeliveryAssignment.new(delivery_assignment_params)
      @delivery_assignment.errors.add(:base, "Failed to create deliveries: #{e.message}")
      load_form_data
      render :new
    rescue => e
      Rails.logger.error "Error creating multi-product deliveries: #{e.message}"
      @delivery_assignment = DeliveryAssignment.new(delivery_assignment_params)
      @delivery_assignment.errors.add(:base, "An error occurred while creating deliveries.")
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
        delivery_schedule_id: delivery_schedule.id,
        discount_amount: delivery_schedule.default_discount_amount || 0
      )
      if assignment.save
        # Calculate and save final amount
        assignment.calculate_final_amount_after_discount
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
        amount: assignment.final_amount,
        due_date: 30.days.from_now,
        status: 'pending'
      )
      
      assignment.update(invoice: invoice)
    rescue => e
      Rails.logger.error "Failed to create invoice for assignment #{assignment.id}: #{e.message}"
    end
  end

  def calculate_delivery_amount
    # Use final amount after discount if available, otherwise calculate normally
    return @delivery_assignment.final_amount if @delivery_assignment.final_amount_after_discount.present?
    
    # Fallback to basic calculation
    base_amount = @delivery_assignment.product&.price || 0
    quantity = @delivery_assignment.quantity || 1
    total = base_amount * quantity
    discount = @delivery_assignment.discount_amount || 0
    [total - discount, 0].max
  end
end