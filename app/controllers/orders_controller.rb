class OrdersController < ApplicationController
  before_action :require_login

  def index
    @delivery_assignments = filter_assignments
                           .includes(:customer, :user, :product)
                           .order(created_at: :desc)
                           .page(params[:page])
                           .per(50)

    @total_count = filter_assignments.count

    # Calculate summary stats for display
    @pending_count = filter_assignments.where(status: ['pending', 'in_progress']).count
    @delivered_count = filter_assignments.where(status: 'completed').count
  end

  private

  def filter_assignments
    assignments = DeliveryAssignment.all

    # Date filter
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