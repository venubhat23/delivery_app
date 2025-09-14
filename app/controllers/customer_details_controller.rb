class CustomerDetailsController < ApplicationController
  before_action :require_login

  def index
    @active_tab = params[:tab] || 'all'

    # Optimized query with proper includes to avoid N+1 queries
    base_includes = [
      :user,
      { delivery_person: [] }, # delivery_person is a User model
      {
        delivery_assignments: [
          :product,
          :user # delivery person for the assignment
        ]
      }
    ]

    case @active_tab
    when 'regular'
      @customers = Customer.regular_customers
                           .includes(base_includes)
                           .order(:name)
                           .page(params[:page])
                           .per(50)
    when 'interval'
      @customers = Customer.interval_customers
                           .includes(base_includes)
                           .order(:name)
                           .page(params[:page])
                           .per(50)
    else # 'all'
      @customers = Customer.all_customers_with_intervals
                           .includes(base_includes)
                           .order(:name)
                           .page(params[:page])
                           .per(50)
    end

    # Preload the most recent delivery assignment for each customer to avoid N+1
    # Using PostgreSQL DISTINCT ON for efficient latest record per customer
    if @customers.present?
      customer_ids = @customers.map(&:id)

      # PostgreSQL DISTINCT ON approach - more efficient than window functions for this use case
      @recent_assignments_by_customer = DeliveryAssignment
        .select('DISTINCT ON (customer_id) customer_id, id, status, scheduled_date, created_at')
        .where(customer_id: customer_ids)
        .order('customer_id, created_at DESC')
        .index_by(&:customer_id)
    else
      @recent_assignments_by_customer = {}
    end

    # Statistics for display - optimize with single query using CASE statements
    # Using raw SQL to avoid GROUP BY issues with .first method
    stats_result = Customer.connection.execute(
      "SELECT COUNT(*) as total_count,
       COUNT(CASE WHEN interval_days = '7' THEN 1 END) as regular_count,
       COUNT(CASE WHEN interval_days::integer < 3 THEN 1 END) as interval_count
       FROM customers
       WHERE interval_days IS NOT NULL"
    ).first

    @stats = {
      regular_count: stats_result['regular_count'].to_i,
      interval_count: stats_result['interval_count'].to_i,
      total_count: stats_result['total_count'].to_i
    }
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

      last_month = 1.month.ago
      current_month = Date.current
      last_month_start = last_month.beginning_of_month
      last_month_end = last_month.end_of_month
      current_month_start = current_month.beginning_of_month
      current_month_end = current_month.end_of_month

      copied_assignments = 0
      copied_schedules = 0
      errors = []

      ActiveRecord::Base.transaction do
        customers.each do |customer|
          # Get completed delivery schedules from last month
          last_month_schedules = customer.delivery_schedules
                                        .select { |s| s.start_date >= last_month_start &&
                                                     s.start_date <= last_month_end &&
                                                     s.status == 'completed' }

          last_month_schedules.each do |schedule|
            # Create new schedule for current month
            new_schedule = schedule.dup
            new_schedule.start_date = current_month_start
            new_schedule.end_date = current_month_end
            new_schedule.status = 'active'
            new_schedule.created_at = Time.current
            new_schedule.updated_at = Time.current

            if new_schedule.save
              copied_schedules += 1

              # Get completed delivery assignments from last month for this schedule
              last_month_assignments = schedule.delivery_assignments
                                              .select { |a| a.scheduled_date >= last_month_start &&
                                                           a.scheduled_date <= last_month_end &&
                                                           a.status == 'completed' }

              last_month_assignments.each do |assignment|
                # Calculate corresponding date in current month
                day_of_month = assignment.scheduled_date.day
                new_date = begin
                  Date.new(current_month.year, current_month.month, day_of_month)
                rescue ArgumentError
                  # Handle cases where the day doesn't exist in current month (e.g., Feb 30)
                  current_month_end
                end

                # Only create if the date is within current month
                if new_date >= current_month_start && new_date <= current_month_end
                  new_assignment = assignment.dup
                  new_assignment.delivery_schedule = new_schedule
                  new_assignment.scheduled_date = new_date
                  new_assignment.status = 'pending'
                  new_assignment.completed_at = nil
                  new_assignment.invoice_generated = false
                  new_assignment.discount_amount = assignment.discount_amount
                  new_assignment.final_amount_after_discount = nil # Will be recalculated
                  new_assignment.created_at = Time.current
                  new_assignment.updated_at = Time.current

                  if new_assignment.save
                    copied_assignments += 1
                  else
                    errors << "Failed to copy assignment for #{customer.name} on #{new_date}: #{new_assignment.errors.full_messages.join(', ')}"
                  end
                end
              end
            else
              errors << "Failed to copy schedule for #{customer.name}: #{new_schedule.errors.full_messages.join(', ')}"
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

  def require_login
    # Add your authentication logic here
    # For example: redirect_to login_path unless logged_in?
  end
end
