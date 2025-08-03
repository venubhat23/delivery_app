class SchedulesController < ApplicationController
  before_action :require_login

  def index
    # Simple page with month/year dropdowns
  end

  def create_schedule
    source_month = params[:month].to_i
    source_year = params[:year].to_i
    current_date = Date.current
    
    # Validate input
    if source_month < 1 || source_month > 12 || source_year < 2020 || source_year > 2030
      render json: { error: 'Invalid month or year selected' }, status: :bad_request
      return
    end

    # Get source date range
    source_start_date = Date.new(source_year, source_month, 1).beginning_of_month
    source_end_date = source_start_date.end_of_month
    
    # Get current month date range
    current_start_date = current_date.beginning_of_month
    current_end_date = current_date.end_of_month

    # Find schedules in the selected month
    source_schedules = DeliverySchedule.includes(:customer, :delivery_assignments)
                                      .where(start_date: source_start_date..source_end_date)
                                      .or(DeliverySchedule.where(end_date: source_start_date..source_end_date))
                                      .or(DeliverySchedule.where('start_date <= ? AND end_date >= ?', source_start_date, source_end_date))

    created_schedules_count = 0
    created_assignments_count = 0
    customers_affected = Set.new
    errors = []

    ActiveRecord::Base.transaction do
      source_schedules.each do |source_schedule|
        begin
          # Calculate new dates for the current month
          new_start_date = calculate_new_date(source_schedule.start_date, source_month, source_year, current_date.month, current_date.year)
          new_end_date = calculate_new_date(source_schedule.end_date, source_month, source_year, current_date.month, current_date.year)
          
          # Skip if dates couldn't be calculated (e.g., 31st doesn't exist in target month)
          next if new_start_date.nil? || new_end_date.nil?
          
          # Create new schedule
          new_schedule = source_schedule.dup
          new_schedule.start_date = new_start_date
          new_schedule.end_date = new_end_date
          new_schedule.status = 'active'
          new_schedule.skip_past_date_validation = true
          
          if new_schedule.save
            created_schedules_count += 1
            customers_affected.add(source_schedule.customer_id)
            
            # Replicate delivery assignments
            source_schedule.delivery_assignments.each do |source_assignment|
              new_assignment_date = calculate_new_date(source_assignment.scheduled_date, source_month, source_year, current_date.month, current_date.year)
              
              # Skip if date couldn't be calculated
              next if new_assignment_date.nil?
              
              new_assignment = source_assignment.dup
              new_assignment.scheduled_date = new_assignment_date
              new_assignment.delivery_schedule = new_schedule
              new_assignment.status = 'pending'
              new_assignment.completed_at = nil
              new_assignment.invoice_generated = false
              new_assignment.invoice_id = nil
              
              if new_assignment.save
                created_assignments_count += 1
              else
                errors << "Failed to create assignment for customer #{source_assignment.customer.name}: #{new_assignment.errors.full_messages.join(', ')}"
              end
            end
          else
            errors << "Failed to create schedule for customer #{source_schedule.customer.name}: #{new_schedule.errors.full_messages.join(', ')}"
          end
        rescue => e
          errors << "Error processing schedule for customer #{source_schedule.customer.name}: #{e.message}"
        end
      end
    end

    # Prepare response
    response_data = {
      success: true,
      summary: {
        schedules_created: created_schedules_count,
        assignments_created: created_assignments_count,
        customers_affected: customers_affected.count,
        source_month: Date.new(source_year, source_month, 1).strftime("%B %Y"),
        target_month: current_date.strftime("%B %Y")
      }
    }
    
    response_data[:errors] = errors if errors.any?
    
    render json: response_data
  end

  def import_last_month
    current_date = Date.current
    last_month_date = current_date - 1.month
    
    # Get last month date range
    source_start_date = last_month_date.beginning_of_month
    source_end_date = last_month_date.end_of_month
    
    # Get current month date range
    current_start_date = current_date.beginning_of_month
    current_end_date = current_date.end_of_month

    # Find schedules in the last month
    source_schedules = DeliverySchedule.includes(:customer, :delivery_assignments)
                                      .where(start_date: source_start_date..source_end_date)
                                      .or(DeliverySchedule.where(end_date: source_start_date..source_end_date))
                                      .or(DeliverySchedule.where('start_date <= ? AND end_date >= ?', source_start_date, source_end_date))

    if source_schedules.empty?
      render json: { 
        error: "No delivery schedules found for #{last_month_date.strftime('%B %Y')}. Please ensure there are schedules to import." 
      }, status: :not_found
      return
    end

    created_schedules_count = 0
    created_assignments_count = 0
    customers_affected = Set.new
    errors = []

    ActiveRecord::Base.transaction do
      source_schedules.each do |source_schedule|
        begin
          # Calculate new dates for the current month
          new_start_date = calculate_new_date(source_schedule.start_date, last_month_date.month, last_month_date.year, current_date.month, current_date.year)
          new_end_date = calculate_new_date(source_schedule.end_date, last_month_date.month, last_month_date.year, current_date.month, current_date.year)
          
          # Skip if dates couldn't be calculated (e.g., 31st doesn't exist in target month)
          next if new_start_date.nil? || new_end_date.nil?
          
          # Check if a similar schedule already exists for this customer, product, and date range
          existing_schedule = DeliverySchedule.where(
            customer_id: source_schedule.customer_id,
            product_id: source_schedule.product_id,
            user_id: source_schedule.user_id,
            start_date: new_start_date,
            end_date: new_end_date
          ).first
          
          if existing_schedule
            errors << "Schedule for customer #{source_schedule.customer.name} with product #{source_schedule.product&.name} already exists for #{current_date.strftime('%B %Y')}"
            next
          end
          
          # Create new schedule
          new_schedule = source_schedule.dup
          new_schedule.start_date = new_start_date
          new_schedule.end_date = new_end_date
          new_schedule.status = 'active'
          new_schedule.skip_past_date_validation = true
          
          if new_schedule.save
            created_schedules_count += 1
            customers_affected.add(source_schedule.customer_id)
            
            # Replicate delivery assignments
            source_schedule.delivery_assignments.each do |source_assignment|
              new_assignment_date = calculate_new_date(source_assignment.scheduled_date, last_month_date.month, last_month_date.year, current_date.month, current_date.year)
              
              # Skip if date couldn't be calculated
              next if new_assignment_date.nil?
              
              # Check if assignment already exists for this date
              existing_assignment = DeliveryAssignment.where(
                customer_id: source_assignment.customer_id,
                user_id: source_assignment.user_id,
                product_id: source_assignment.product_id,
                scheduled_date: new_assignment_date
              ).first
              
              if existing_assignment
                next # Skip this assignment as it already exists
              end
              
              new_assignment = source_assignment.dup
              new_assignment.scheduled_date = new_assignment_date
              new_assignment.delivery_schedule = new_schedule
              new_assignment.status = 'pending'
              new_assignment.completed_at = nil
              new_assignment.invoice_generated = false
              new_assignment.invoice_id = nil
              
              if new_assignment.save
                created_assignments_count += 1
              else
                errors << "Failed to create assignment for customer #{source_assignment.customer.name} on #{new_assignment_date.strftime('%B %d, %Y')}: #{new_assignment.errors.full_messages.join(', ')}"
              end
            end
          else
            errors << "Failed to create schedule for customer #{source_schedule.customer.name}: #{new_schedule.errors.full_messages.join(', ')}"
          end
        rescue => e
          errors << "Error processing schedule for customer #{source_schedule.customer.name}: #{e.message}"
        end
      end
    end

    # Prepare response
    response_data = {
      success: true,
      summary: {
        schedules_created: created_schedules_count,
        assignments_created: created_assignments_count,
        customers_affected: customers_affected.count,
        source_month: last_month_date.strftime("%B %Y"),
        target_month: current_date.strftime("%B %Y")
      }
    }
    
    response_data[:errors] = errors if errors.any?
    
    render json: response_data
  end

  private

  def calculate_new_date(original_date, source_month, source_year, target_month, target_year)
    return nil if original_date.nil?
    
    # Calculate the day of the month
    original_day = original_date.day
    
    # Try to create the new date
    begin
      Date.new(target_year, target_month, original_day)
    rescue Date::Error
      # If the day doesn't exist in the target month (e.g., 31st in February), return nil
      nil
    end
  end
end