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

  def import_selected_month
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

    # Find delivery assignments in the selected month
    source_assignments = DeliveryAssignment.includes(:customer, :product, :user)
                                          .where(scheduled_date: source_start_date..source_end_date)
                                          .order(:scheduled_date)

    if source_assignments.empty?
      render json: {
        error: "No delivery assignments found for #{source_start_date.strftime('%B %Y')}. Please ensure there are assignments to import."
      }, status: :not_found
      return
    end

    created_assignments_count = 0
    customers_affected = Set.new
    errors = []

    # Pre-group assignments by day for efficient processing (this fixes the infinite loop issue)
    assignments_by_day = source_assignments.group_by { |a| a.scheduled_date.day }

    ActiveRecord::Base.transaction do
      # Handle date mapping for different month lengths
      source_month_days = source_end_date.day
      target_month_days = current_end_date.day

      # Pre-fetch existing assignments for the entire current month to reduce queries
      existing_assignments_set = Set.new
      DeliveryAssignment.where(scheduled_date: current_start_date..current_end_date)
                       .select(:customer_id, :user_id, :product_id, :scheduled_date)
                       .find_each do |assignment|
        key = "#{assignment.customer_id}-#{assignment.user_id}-#{assignment.product_id}-#{assignment.scheduled_date}"
        existing_assignments_set.add(key)
      end

      # Process each target day once (this prevents the infinite loop)
      (1..target_month_days).each do |target_day|
        begin
          source_day = target_day

          # If target month has more days than source month, use the last day of source month for extra days
          if target_day > source_month_days
            source_day = source_month_days
          end

          # Get assignments for this source day using pre-grouped hash (O(1) lookup instead of O(n) search)
          day_assignments = assignments_by_day[source_day] || []

          # Skip if no assignments for this day
          next if day_assignments.empty?

          target_date = Date.new(current_date.year, current_date.month, target_day)

          # Skip if target date couldn't be calculated
          next if target_date.nil?

          # Process assignments for this day
          day_assignments.each do |source_assignment|
            begin
              # Check if assignment already exists using in-memory set (much faster than DB query)
              assignment_key = "#{source_assignment.customer_id}-#{source_assignment.user_id}-#{source_assignment.product_id}-#{target_date}"

              if existing_assignments_set.include?(assignment_key)
                next # Skip this assignment as it already exists
              end

              # Create new assignment
              new_assignment = source_assignment.dup
              new_assignment.scheduled_date = target_date
              new_assignment.delivery_schedule_id = nil # Remove schedule association for now
              new_assignment.status = 'pending'
              new_assignment.completed_at = nil
              new_assignment.invoice_generated = false
              new_assignment.invoice_id = nil

              if new_assignment.save
                created_assignments_count += 1
                customers_affected.add(source_assignment.customer_id)
                # Add to our existing set to prevent duplicate creation within this transaction
                existing_assignments_set.add(assignment_key)
              else
                errors << "Failed to create assignment for customer #{source_assignment.customer.name} on #{target_date.strftime('%B %d, %Y')}: #{new_assignment.errors.full_messages.join(', ')}"
              end
            rescue => e
              errors << "Error processing assignment for customer #{source_assignment.customer&.name || 'Unknown'} on #{target_date.strftime('%B %d, %Y')}: #{e.message}"
            end
          end
        rescue => e
          errors << "Error processing assignments for day #{target_day}: #{e.message}"
        end
      end
    end

    # Prepare response
    response_data = {
      success: true,
      summary: {
        schedules_created: 0, # We're not creating schedules, just assignments
        assignments_created: created_assignments_count,
        customers_affected: customers_affected.count,
        source_month: source_start_date.strftime("%B %Y"),
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

  def calculate_target_date(source_day, source_month, source_year, target_month, target_year, source_month_last_day)
    return nil if source_day.nil? || source_month.nil? || source_year.nil? || target_month.nil? || target_year.nil?

    # Get the last day of the target month
    target_month_last_day = Date.new(target_year, target_month, 1).end_of_month.day
    
    # If the source day exists in the target month, use it directly
    if source_day <= target_month_last_day
      begin
        return Date.new(target_year, target_month, source_day)
      rescue Date::Error
        return nil
      end
    end
    
    # If the source day doesn't exist in the target month (e.g., 31st in a 30-day month)
    # but the target month has more days than the source month, use the last day of the source month
    if target_month_last_day >= source_month_last_day
      begin
        return Date.new(target_year, target_month, source_month_last_day)
      rescue Date::Error
        return nil
      end
    end
    
    # If the target month has fewer days, skip this date
    return nil
  end
end