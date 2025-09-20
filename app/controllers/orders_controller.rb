class OrdersController < ApplicationController
  before_action :require_login

  def index
    # Use base query without select for counting
    base_query = filter_assignments_for_count

    # Get paginated results with includes to prevent N+1 queries
    @delivery_assignments = filter_assignments
                           .includes(:customer, :user, :product)
                           .order(created_at: :desc)
                           .page(params[:page])
                           .per(50)

    # Calculate all counts in a single query using group
    counts = base_query.group(:status).count
    @total_count = counts.values.sum
    @pending_count = counts['pending'].to_i + counts['in_progress'].to_i
    @delivered_count = counts['completed'].to_i
  end

  private

  def filter_assignments
    # Use full model for better compatibility with view methods
    assignments = DeliveryAssignment.all

    # Date filter (apply early to reduce dataset)
    assignments = apply_date_filter(assignments)

    # Booked by filter
    assignments = apply_booked_by_filter(assignments)

    assignments
  end

  def filter_assignments_for_count
    # Use base query without select for counting operations
    assignments = DeliveryAssignment.all

    # Date filter (apply early to reduce dataset)
    assignments = apply_date_filter(assignments)

    # Booked by filter
    assignments = apply_booked_by_filter(assignments)

    assignments
  end

  def apply_date_filter(assignments)
    case params[:date_filter]
    when 'today'
      assignments.where(scheduled_date: Date.current)
    when 'weekly'
      start_date = Date.current.beginning_of_week
      end_date = Date.current.end_of_week
      assignments.where(scheduled_date: start_date..end_date)
    when 'monthly'
      start_date = Date.current.beginning_of_month
      end_date = Date.current.end_of_month
      assignments.where(scheduled_date: start_date..end_date)
    when 'custom'
      if params[:start_date].present? && params[:end_date].present?
        start_date = Date.parse(params[:start_date])
        end_date = Date.parse(params[:end_date])
        assignments.where(scheduled_date: start_date..end_date)
      else
        assignments
      end
    else
      # Default to today
      assignments.where(scheduled_date: Date.current)
    end
  rescue Date::Error
    # If date parsing fails, return all assignments
    assignments
  end

  def apply_booked_by_filter(assignments)
    return assignments unless params[:booked_by_filter].present?

    case params[:booked_by_filter]
    when 'customer'
      assignments.booked_by_customer
    when 'delivery_person'
      assignments.booked_by_delivery_person
    when 'admin'
      assignments.booked_by_admin
    else
      assignments
    end
  end
end