require 'csv'

class DeliveryReviewController < ApplicationController
  before_action :require_login
  before_action :require_admin_or_delivery_team
  
  def index
    # Load data for dropdowns
    @customers = Customer.active.order(:name)
    @delivery_persons = User.delivery_people.order(:name)
    @products = Product.where(is_active: true).order(:name)
    
    # Initial empty state - data will be loaded via AJAX
    @deliveries = []
    @summary = {}
  end

  def data
    # Apply filters and get total count first
    all_filtered_deliveries = filtered_deliveries
    total_count = all_filtered_deliveries.count
    
    # Then limit for performance on the actual display
    @deliveries = all_filtered_deliveries.limit(1000)
    @summary = calculate_summary(all_filtered_deliveries)
    respond_to do |format|
      format.json { 
        render json: { 
          deliveries: deliveries_json,
          summary: @summary,
          has_more: total_count > 1000,
          total_count: total_count
        } 
      }
      format.html { render partial: 'delivery_table' }
    end
  end

  def export
    @deliveries = filtered_deliveries
    
    csv_data = CSV.generate(headers: true) do |csv|
      csv << [
        'Date', 'Customer Name', 'Product', 'Quantity', 'Amount', 'Product Cost', 'Status', 'Delivery Person'
      ]

      @deliveries.find_each do |delivery|
        # Calculate proportional amount for export
        base_rate_per_liter = 200.0
        proportional_amount = (delivery.quantity.to_f * base_rate_per_liter).round(2)
        
        # Calculate product cost: quantity × proportional_amount
        product_cost = (delivery.quantity.to_f * proportional_amount).round(2)
        
        csv << [
          delivery.scheduled_date.strftime('%d.%m.%Y'),
          delivery.customer&.name,
          delivery.product&.name,
          "#{delivery.quantity} #{delivery.unit}",
          proportional_amount,
          product_cost,
          delivery.status,
          delivery.delivery_person&.name || 'Not Assigned'
        ]
      end
    end

    send_data csv_data,
              filename: "delivery_review_#{Date.current.strftime('%d%m%Y')}.csv",
              type: 'text/csv',
              disposition: 'attachment'
  end

  def update
    @delivery = DeliveryAssignment.find(params[:id])
    
    if @delivery.update(delivery_params)
      render json: { success: true, message: 'Delivery updated successfully' }
    else
      render json: { success: false, errors: @delivery.errors.full_messages }
    end
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, message: 'Delivery not found' }, status: 404
  end

  def destroy
    @delivery = DeliveryAssignment.find(params[:id])
    
    if @delivery.destroy
      render json: { success: true, message: 'Delivery deleted successfully' }
    else
      render json: { success: false, message: 'Failed to delete delivery' }
    end
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, message: 'Delivery not found' }, status: 404
  end

  def bulk_complete
    assignment_ids = params[:assignment_ids]
    
    if assignment_ids.blank?
      render json: { success: false, message: 'No assignments provided' }, status: 400
      return
    end
    
    # Find pending assignments with the provided IDs
    assignments = DeliveryAssignment.where(
      id: assignment_ids,
      status: 'pending'
    )
    
    completed_count = 0
    failed_count = 0
    
    assignments.find_each do |assignment|
      if assignment.update(status: 'completed', completed_at: Time.current)
        completed_count += 1
      else
        failed_count += 1
      end
    end
    
    if completed_count > 0
      message = "Successfully completed #{completed_count} delivery assignment(s)."
      message += " #{failed_count} failed to update." if failed_count > 0
      render json: { 
        success: true, 
        message: message,
        completed_count: completed_count,
        failed_count: failed_count
      }
    else
      render json: { 
        success: false, 
        message: 'No pending assignments found to complete.' 
      }
    end
  rescue => e
    Rails.logger.error "Bulk completion error: #{e.message}"
    render json: { success: false, message: 'Failed to complete assignments' }, status: 500
  end

  private

  def require_admin_or_delivery_team
    unless current_user&.admin? || current_user&.delivery_person?
      redirect_to root_path
    end
  end

  def filtered_deliveries
    scope = DeliveryAssignment.includes(:customer, :product, :delivery_person)
    
    # Apply customer filter
    if params[:customer_id].present? && params[:customer_id] != 'all'
      scope = scope.where(customer_id: params[:customer_id])
    end
    
    # Apply date filter
    scope = apply_date_filter(scope)
    
    # Apply product filter if present
    if params[:product_id].present? && params[:product_id] != 'all'
      scope = scope.where(product_id: params[:product_id])
    end
    
    # Apply status filter if present
    if params[:status].present? && params[:status] != 'all'
      scope = scope.where(status: params[:status])
    end
    
    # Apply delivery person filter if present
    if params[:delivery_person_id].present? && params[:delivery_person_id] != 'all'
      scope = scope.where(user_id: params[:delivery_person_id])
    end
    
    # Search functionality
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      scope = scope.joins(:customer)
                   .where("customers.name ILIKE ? OR customers.phone_number ILIKE ? OR customers.member_id ILIKE ?", 
                          search_term, search_term, search_term)
    end
    
    scope = scope.joins(:customer)
    scope.order(scheduled_date: :desc, 'customers.name': :asc)
  end

  def apply_date_filter(scope)
    filter_type = params[:date_filter] || 'monthly'
    
    case filter_type
    when 'today'
      scope.where(scheduled_date: Date.current)
    when 'weekly'
      start_date = Date.current.beginning_of_week
      end_date = Date.current.end_of_week
      scope.where(scheduled_date: start_date..end_date)
    when 'monthly'
      start_date = Date.current.beginning_of_month
      end_date = Date.current.end_of_month
      scope.where(scheduled_date: start_date..end_date)
    when 'custom'
      if params[:start_date].present? && params[:end_date].present?
        begin
          # Handle YYYY-MM-DD format (standard HTML5 date input format)
          start_date = Date.parse(params[:start_date])
          end_date = Date.parse(params[:end_date])
          scope.where(scheduled_date: start_date..end_date)
        rescue ArgumentError
          # Fallback to current month if date parsing fails
          scope.where(scheduled_date: Date.current.beginning_of_month..Date.current.end_of_month)
        end
      else
        scope.where(scheduled_date: Date.current.beginning_of_month..Date.current.end_of_month)
      end
    else
      scope.where(scheduled_date: Date.current.beginning_of_month..Date.current.end_of_month)
    end
  end

  def calculate_summary(deliveries = @deliveries)
    # Use SQL aggregation to avoid N+1 queries
    base_rate_per_liter = 200.0
    
    # Remove ordering from the deliveries query for summary calculations to avoid PostgreSQL GROUP BY errors
    summary_query = deliveries.reorder('')
    
    # Calculate totals using SQL
    summary_data = summary_query.group(:status).count
    total_deliveries = summary_data.values.sum
    total_customers = summary_query.distinct.count(:customer_id)
    
    # Calculate total product cost using SQL: sum(quantity * quantity * base_rate_per_liter)
    # This is equivalent to: sum(quantity × proportional_amount) where proportional_amount = quantity × base_rate_per_liter
    total_amount = summary_query.sum("final_amount_after_discount")
    
    completed_deliveries = summary_data['completed'] || 0
    pending_deliveries = summary_data['pending'] || 0
    cancelled_deliveries = summary_data['cancelled'] || 0
    in_progress_deliveries = summary_data['in_progress'] || 0
    
    completion_rate = total_deliveries > 0 ? ((completed_deliveries.to_f / total_deliveries) * 100).round(1) : 0
    
    {
      total_deliveries: total_deliveries,
      total_customers: total_customers,
      total_amount: total_amount.round(2),
      completion_rate: completion_rate,
      completed_deliveries: completed_deliveries,
      pending_deliveries: pending_deliveries,
      cancelled_deliveries: cancelled_deliveries,
      in_progress_deliveries: in_progress_deliveries
    }
  end

  def deliveries_json
    @deliveries.map do |delivery|
      # Calculate proportional amount: if 1L = ₹200, then 0.5L = ₹100
      base_rate_per_liter = 200.0
      proportional_amount = (delivery.quantity.to_f * delivery.final_amount_after_discount.to_i).round(2)
      # Calculate product cost: quantity × proportional_amount
      product_cost = (delivery.quantity.to_f * delivery.final_amount_after_discount.to_i).round(2)
      {
        id: delivery.id,
        date: delivery.scheduled_date.strftime('%d.%m.%Y'),
        customer_name: delivery.customer.name,
        customer_phone: delivery.customer.phone_number,
        customer_member_id: delivery.customer.member_id,
        product: delivery.product.name,
        quantity: "#{delivery.quantity} #{delivery.unit}",
        amount: delivery.product.price.to_f,
        discount: delivery.discount_amount.to_f,
        product_cost: delivery.final_amount_after_discount.to_i,
        original_amount: delivery.final_amount_after_discount || 0,
        status: delivery.status,
        delivery_person: delivery.delivery_person&.name || 'Not Assigned',
        special_instructions: delivery.special_instructions
      }
    end
  end

  def delivery_params
    # Handle both direct delivery_assignment params and nested delivery_review[delivery_assignment] params
    if params[:delivery_review].present? && params[:delivery_review][:delivery_assignment].present?
      # Use nested params - permit first, then filter
      permitted_params = params[:delivery_review][:delivery_assignment].permit(:product_id, :quantity, :scheduled_date, :final_amount_after_discount, :status, :user_id)
      
      # Convert to hash for filtering
      assignment_params = permitted_params.to_h
      assignment_params = assignment_params.reject { |k, v| k == 'undefined' || k.blank? }
      
      # Handle the case where 'undefined' key contains the actual status value
      if assignment_params.has_key?('undefined') && assignment_params['status'].blank?
        assignment_params['status'] = assignment_params.delete('undefined')
      end
      
      ActionController::Parameters.new(assignment_params).permit!
    elsif params[:delivery_assignment].present?
      # Use direct params - permit first, then filter
      permitted_params = params[:delivery_assignment].permit(:product_id, :quantity, :scheduled_date, :final_amount_after_discount, :status, :user_id)
      
      # Convert to hash for filtering
      assignment_params = permitted_params.to_h
      assignment_params = assignment_params.reject { |k, v| k == 'undefined' || k.blank? }
      
      # Handle the case where 'undefined' key contains the actual status value
      if assignment_params.has_key?('undefined') && assignment_params['status'].blank?
        assignment_params['status'] = assignment_params.delete('undefined')
      end
      
      ActionController::Parameters.new(assignment_params).permit!
    else
      # Fallback to empty permitted params
      ActionController::Parameters.new({}).permit(:product_id, :quantity, :scheduled_date, :final_amount_after_discount, :status, :user_id)
    end
  end
end