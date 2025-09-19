class CustomerDetailsController < ApplicationController
  before_action :require_login

  def index
    @active_tab = params[:tab] || 'all'

    # Highly optimized query to minimize database hits
    case @active_tab
    when 'regular'
      base_query = Customer.regular_customers
    when 'interval'
      base_query = Customer.interval_customers
    else # 'all'
      base_query = Customer.all_customers_with_intervals
    end

    # Single optimized query with all necessary includes
    @customers = base_query
                  .includes(
                    :user,
                    :delivery_person,
                    delivery_assignments: [:product, :user]
                  )
                  .order(:name)
                  .page(params[:page])
                  .per(50)

    # Preload recent assignments efficiently in a single query
    if @customers.present?
      customer_ids = @customers.map(&:id)

      # Single optimized query for recent assignments with all associations
      @recent_assignments_by_customer = DeliveryAssignment
        .includes(:product, :user)
        .select('DISTINCT ON (customer_id) customer_id, id, status, scheduled_date, created_at, product_id, user_id')
        .where(customer_id: customer_ids)
        .order('customer_id, created_at DESC')
        .index_by(&:customer_id)
    else
      @recent_assignments_by_customer = {}
    end

    # Single efficient statistics query
    @stats = Rails.cache.fetch("customer_stats_#{Customer.maximum(:updated_at)}", expires_in: 5.minutes) do
      stats_result = Customer.connection.execute(
        "SELECT COUNT(*) as total_count,
         COUNT(CASE WHEN interval_days = '7' THEN 1 END) as regular_count,
         COUNT(CASE WHEN interval_days::integer < 3 THEN 1 END) as interval_count
         FROM customers
         WHERE interval_days IS NOT NULL"
      ).first

      {
        regular_count: stats_result['regular_count'].to_i,
        interval_count: stats_result['interval_count'].to_i,
        total_count: stats_result['total_count'].to_i
      }
    end
  end

  def copy_from_last_month
    customer_ids = params[:customer_ids]

    if customer_ids.blank?
      flash[:alert] = "Please select at least one customer."
      redirect_to customer_details_path(tab: 'regular') and return
    end

    begin
      # Preload all necessary data to avoid N+1 queries
      customers = Customer.where(id: customer_ids)
                         .includes(
                           delivery_schedules: {
                             delivery_assignments: [:product]
                           }
                         )

      if customers.empty?
        flash[:alert] = "No valid customers found."
        redirect_to customer_details_path(tab: 'regular') and return
      end

      # Get the actual last month and current month
      today = Date.current
      current_month_start = today.beginning_of_month
      current_month_end = today.end_of_month

      # Last month is the previous month
      last_month_date = today.prev_month
      last_month_start = last_month_date.beginning_of_month
      last_month_end = last_month_date.end_of_month

      # Get the number of days in each month
      last_month_days = last_month_end.day
      current_month_days = current_month_end.day

      copied_assignments = 0
      copied_schedules = 0
      errors = []

      ActiveRecord::Base.transaction do
        customers.each do |customer|
          Rails.logger.info "Processing customer #{customer.name} (ID: #{customer.id})"
          Rails.logger.info "Looking for assignments between #{last_month_start} and #{last_month_end}"

          # Get ALL delivery assignments from last month (regardless of status)
          last_month_assignments = DeliveryAssignment
                                    .where(customer_id: customer.id)
                                    .where(scheduled_date: last_month_start..last_month_end)
                                    .includes(:product, :user, :delivery_schedule)

          Rails.logger.info "Found #{last_month_assignments.count} assignments for customer #{customer.name}"

          # Check for assignments without delivery schedules
          assignments_without_schedule = last_month_assignments.select { |a| a.delivery_schedule.nil? }
          if assignments_without_schedule.any?
            Rails.logger.warn "Found #{assignments_without_schedule.count} assignments without delivery_schedule for customer #{customer.name}"
          end

          if last_month_assignments.any?
            # Separate assignments with and without delivery schedules
            assignments_with_schedule = last_month_assignments.select { |a| a.delivery_schedule.present? }
            assignments_without_schedule = last_month_assignments.select { |a| a.delivery_schedule.nil? }

            # Handle assignments with schedules
            if assignments_with_schedule.any?
              assignments_by_schedule = assignments_with_schedule.group_by(&:delivery_schedule)
              Rails.logger.info "Grouped into #{assignments_by_schedule.keys.count} delivery schedules"

              assignments_by_schedule.each do |schedule, assignments|
                next if schedule.nil?
                result = copy_schedule_and_assignments(schedule, assignments, current_month_start, current_month_end, current_month_days, last_month_days, customer, errors)
                copied_schedules += result[:schedules] if result
                copied_assignments += result[:assignments] if result
              end
            end

            # Handle assignments without schedules - create a default schedule
            if assignments_without_schedule.any?
              Rails.logger.info "Creating default schedule for #{assignments_without_schedule.count} assignments without schedule"

              # Create a default delivery schedule
              default_schedule = DeliverySchedule.new(
                customer: customer,
                user: assignments_without_schedule.first.user || customer.delivery_person,
                product: assignments_without_schedule.first.product,
                frequency: 'daily',
                start_date: current_month_start,
                end_date: current_month_end,
                status: 'active',
                created_at: Time.current,
                updated_at: Time.current
              )

              if default_schedule.save
                copied_schedules += 1
                result = copy_schedule_and_assignments(nil, assignments_without_schedule, current_month_start, current_month_end, current_month_days, last_month_days, customer, errors, default_schedule)
                copied_assignments += result[:assignments] if result
              else
                errors << "Failed to create default schedule for #{customer.name}: #{default_schedule.errors.full_messages.join(', ')}"
              end
            end
          end
        end
      end

      if errors.any?
        flash[:alert] = "Some assignments could not be copied: #{errors.join('; ')}"
      else
        flash[:notice] = "Successfully copied #{copied_schedules} schedule(s) and #{copied_assignments} assignment(s) from last month for #{customers.count} customer(s)."
      end

    rescue => e
      Rails.logger.error "Error copying from last month: #{e.message}"
      flash[:alert] = "An error occurred while copying assignments: #{e.message}"
    end

    redirect_to customer_details_path(tab: 'regular')
  end

  private

  def copy_schedule_and_assignments(original_schedule, assignments, current_month_start, current_month_end, current_month_days, last_month_days, customer, errors, new_schedule = nil)
    schedule_count = 0
    assignment_count = 0

    # Create new schedule for current month (or use provided one)
    if new_schedule.nil?
      new_schedule = original_schedule.dup
      new_schedule.start_date = current_month_start
      new_schedule.end_date = current_month_end
      new_schedule.status = 'active'
      new_schedule.created_at = Time.current
      new_schedule.updated_at = Time.current

      unless new_schedule.save
        errors << "Failed to copy schedule for #{customer.name}: #{new_schedule.errors.full_messages.join(', ')}"
        return nil
      end
      schedule_count = 1
    end

    # Create assignments for each day that had assignments last month
    assignments.each do |assignment|
      last_month_day = assignment.scheduled_date.day
      Rails.logger.info "Copying assignment from #{assignment.scheduled_date} (day #{last_month_day})"

      # Create assignment for the same day number in current month (if it exists)
      if last_month_day <= current_month_days
        new_date = Date.new(current_month_start.year, current_month_start.month, last_month_day)
        Rails.logger.info "Creating new assignment for #{new_date}"
        if create_assignment_copy(new_schedule, assignment, new_date, customer, errors)
          assignment_count += 1
          Rails.logger.info "Successfully created assignment for #{new_date}"
        end
      end
    end

    # If current month has more days than last month, extend the pattern
    if current_month_days > last_month_days
      # Create assignments for the additional days based on the pattern
      (last_month_days + 1..current_month_days).each do |extra_day|
        # Find a reference assignment from the same day of the week in last month
        target_date = Date.new(current_month_start.year, current_month_start.month, extra_day)
        target_wday = target_date.wday # 0=Sunday, 1=Monday, etc.

        # Look for assignments on the same weekday in last month
        reference_assignment = assignments.find do |a|
          a.scheduled_date.wday == target_wday
        end

        # If no exact weekday match, use the last assignment as template
        reference_assignment ||= assignments.last

        if reference_assignment
          if create_assignment_copy(new_schedule, reference_assignment, target_date, customer, errors)
            assignment_count += 1
          end
        end
      end
    end

    { schedules: schedule_count, assignments: assignment_count }
  end

  def create_assignment_copy(new_schedule, original_assignment, new_date, customer, errors)
    new_assignment = original_assignment.dup
    new_assignment.delivery_schedule = new_schedule
    new_assignment.scheduled_date = new_date
    new_assignment.status = 'pending'
    new_assignment.completed_at = nil
    new_assignment.invoice_generated = false
    new_assignment.discount_amount = original_assignment.discount_amount
    new_assignment.final_amount_after_discount = nil # Will be recalculated
    new_assignment.created_at = Time.current
    new_assignment.updated_at = Time.current

    if new_assignment.save
      return true
    else
      errors << "Failed to copy assignment for #{customer.name} on #{new_date}: #{new_assignment.errors.full_messages.join(', ')}"
      return false
    end
  end

  def require_login
    # Add your authentication logic here
    # For example: redirect_to login_path unless logged_in?
  end
end
