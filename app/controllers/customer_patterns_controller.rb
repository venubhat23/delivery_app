class CustomerPatternsController < ApplicationController
  before_action :require_login

  def index
    @current_month = params[:month]&.to_i || Date.current.month
    @current_year = params[:year]&.to_i || Date.current.year
    @delivery_person_id = params[:delivery_person_id].presence

    # Get all delivery people for the dropdown
    @delivery_people = User.where(role: 'delivery_person').order(:name)

    # Cache key includes delivery person filter
    cache_key = "customer_patterns_#{@current_month}_#{@current_year}_#{@delivery_person_id}"

    # Get customer patterns with caching and delivery person filtering
    @customer_patterns = Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
      Customer.analyze_monthly_patterns(@current_month, @current_year, @delivery_person_id)
    end

    # Group by pattern type for summary
    @pattern_summary = @customer_patterns.group_by { |data| data[:pattern] }

    # Calculate totals
    @total_customers = @customer_patterns.length
    @regular_count = @pattern_summary['regular']&.length || 0
    @interval_count = @pattern_summary['interval']&.length || 0
    @irregular_count = @pattern_summary['irregular']&.length || 0

    @month_name = Date.new(@current_year, @current_month, 1).strftime("%B %Y")

    # Filter by pattern if requested
    if params[:pattern].present?
      @customer_patterns = @customer_patterns.select { |data| data[:pattern] == params[:pattern] }
    end

    # Sort by customer name
    @customer_patterns = @customer_patterns.sort_by { |data| data[:customer].name }
  end

  def customer_deliveries
    @customer = Customer.find(params[:customer_id])
    @month = params[:month]&.to_i || Date.current.month
    @year = params[:year]&.to_i || Date.current.year

    start_date = Date.new(@year, @month, 1).beginning_of_month
    end_date = start_date.end_of_month

    @delivery_assignments = DeliveryAssignment
      .includes(:customer, :user, :product, :delivery_schedule)
      .where(customer_id: @customer.id, scheduled_date: start_date..end_date)
      .order(:scheduled_date)

    @month_name = start_date.strftime("%B %Y")

    respond_to do |format|
      format.json { render json: { html: render_to_string(partial: 'delivery_assignments_modal', layout: false, formats: [:html]) } }
    end
  end

  def complete_till_today
    @customer = Customer.find(params[:customer_id])
    month = params[:month]&.to_i || Date.current.month
    year = params[:year]&.to_i || Date.current.year

    start_date = Date.new(year, month, 1).beginning_of_month
    end_date = start_date.end_of_month

    # Find pending assignments till today for this customer in the selected month
    assignments_to_complete = DeliveryAssignment
      .where(customer_id: @customer.id)
      .where(status: 'pending')
      .where(scheduled_date: start_date..Date.current)
      .where(scheduled_date: start_date..end_date)

    completed_count = 0
    assignments_to_complete.each do |assignment|
      if assignment.update(status: 'completed', completed_at: Time.current)
        completed_count += 1
      end
    end

    respond_to do |format|
      format.json {
        render json: {
          success: true,
          message: "✅ #{completed_count} assignments marked as completed",
          completed_count: completed_count
        }
      }
    end
  rescue => e
    respond_to do |format|
      format.json {
        render json: {
          success: false,
          message: "❌ Error completing assignments: #{e.message}"
        }
      }
    end
  end

  def edit_assignment
    @assignment = DeliveryAssignment.find(params[:id])

    respond_to do |format|
      format.json {
        render json: {
          html: render_to_string(partial: 'edit_assignment_modal', locals: { assignment: @assignment }, layout: false, formats: [:html])
        }
      }
    end
  end

  def update_assignment
    @assignment = DeliveryAssignment.find(params[:id])

    if @assignment.update(assignment_params)
      respond_to do |format|
        format.json {
          render json: {
            success: true,
            message: "✅ Assignment updated successfully"
          }
        }
      end
    else
      respond_to do |format|
        format.json {
          render json: {
            success: false,
            message: "❌ Error updating assignment: #{@assignment.errors.full_messages.join(', ')}"
          }
        }
      end
    end
  end

  def delete_assignment
    @assignment = DeliveryAssignment.find(params[:id])

    if @assignment.destroy
      respond_to do |format|
        format.json {
          render json: {
            success: true,
            message: "🗑️ Assignment deleted successfully"
          }
        }
      end
    else
      respond_to do |format|
        format.json {
          render json: {
            success: false,
            message: "❌ Error deleting assignment"
          }
        }
      end
    end
  end

  def get_pending_count
    month = params[:month]&.to_i || Date.current.month
    year = params[:year]&.to_i || Date.current.year
    delivery_person_id = params[:delivery_person_id].presence

    start_date = Date.new(year, month, 1).beginning_of_month
    end_date = start_date.end_of_month

    query = DeliveryAssignment
      .where(status: 'pending')
      .where(scheduled_date: start_date..Date.current)
      .where(scheduled_date: start_date..end_date)

    if delivery_person_id.present?
      query = query.where(user_id: delivery_person_id)
    end

    pending_count = query.count

    respond_to do |format|
      format.json {
        render json: {
          pending_count: pending_count,
          month_name: start_date.strftime("%B %Y")
        }
      }
    end
  end

  def complete_all_till_today
    month = params[:month]&.to_i || Date.current.month
    year = params[:year]&.to_i || Date.current.year
    delivery_person_id = params[:delivery_person_id].presence

    start_date = Date.new(year, month, 1).beginning_of_month
    end_date = start_date.end_of_month

    # Find all pending assignments till today for the selected month/filters
    query = DeliveryAssignment
      .where(status: 'pending')
      .where(scheduled_date: start_date..Date.current)
      .where(scheduled_date: start_date..end_date)

    if delivery_person_id.present?
      query = query.where(user_id: delivery_person_id)
    end

    assignments_to_complete = query.includes(:customer, :user)

    completed_count = 0
    customers_affected = []
    delivery_people_affected = []

    assignments_to_complete.each do |assignment|
      if assignment.update(status: 'completed', completed_at: Time.current)
        completed_count += 1
        customers_affected << assignment.customer.name unless customers_affected.include?(assignment.customer.name)
        delivery_people_affected << assignment.user.name unless delivery_people_affected.include?(assignment.user.name)
      end
    end

    respond_to do |format|
      format.json {
        render json: {
          success: true,
          completed_count: completed_count,
          customers_affected: customers_affected.size,
          delivery_people_affected: delivery_people_affected.size,
          message: "✅ #{completed_count} assignments completed for #{customers_affected.size} customers and #{delivery_people_affected.size} delivery people"
        }
      }
    end
  rescue => e
    respond_to do |format|
      format.json {
        render json: {
          success: false,
          message: "❌ Error completing assignments: #{e.message}"
        }
      }
    end
  end

  def remove_all_assignments
    @customer = Customer.find(params[:customer_id])
    month = params[:month]&.to_i || Date.current.month
    year = params[:year]&.to_i || Date.current.year

    start_date = Date.new(year, month, 1).beginning_of_month
    end_date = start_date.end_of_month

    # Find all assignments for this customer in the selected month
    assignments_to_delete = DeliveryAssignment
      .where(customer_id: @customer.id)
      .where(scheduled_date: start_date..end_date)

    deleted_count = assignments_to_delete.count

    # Delete all assignments
    assignments_to_delete.destroy_all

    respond_to do |format|
      format.json {
        render json: {
          success: true,
          message: "🗑️ All #{deleted_count} assignments for #{@customer.name} have been removed successfully",
          deleted_count: deleted_count
        }
      }
    end
  rescue => e
    respond_to do |format|
      format.json {
        render json: {
          success: false,
          message: "❌ Error removing assignments: #{e.message}"
        }
      }
    end
  end

  private

  def assignment_params
    params.require(:delivery_assignment).permit(:quantity, :discount_amount, :status, :scheduled_date)
  end
end
