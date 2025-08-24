class DeliveryReviewController < ApplicationController
  before_action :require_login
  
  def index
    # Load data for dropdowns
    @customers = Customer.active.order(:name)
    @delivery_persons = User.delivery_team.order(:name)
    
    # Initial empty state - data will be loaded via AJAX
    @deliveries = []
    @summary = {}
  end

  def data
    # Apply filters and return data as JSON
    @deliveries = filtered_deliveries.limit(1000) # Limit for performance
    @summary = calculate_summary
    
    respond_to do |format|
      format.json { 
        render json: { 
          deliveries: deliveries_json,
          summary: @summary,
          has_more: @deliveries.count >= 1000
        } 
      }
      format.html { render partial: 'delivery_table' }
    end
  end

  def export
    @deliveries = filtered_deliveries
    
    respond_to do |format|
      format.csv { 
        headers['Content-Disposition'] = "attachment; filename=\"delivery_review_#{Date.current.strftime('%Y%m%d')}.csv\""
        headers['Content-Type'] = 'text/csv'
      }
    end
  end

  private

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
                   .where("customers.name ILIKE ? OR customers.phone ILIKE ? OR customers.member_id ILIKE ?", 
                          search_term, search_term, search_term)
    end
    
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
          start_date = Date.parse(params[:start_date])
          end_date = Date.parse(params[:end_date])
          scope.where(scheduled_date: start_date..end_date)
        rescue ArgumentError
          scope.where(scheduled_date: Date.current.beginning_of_month..Date.current.end_of_month)
        end
      else
        scope.where(scheduled_date: Date.current.beginning_of_month..Date.current.end_of_month)
      end
    else
      scope.where(scheduled_date: Date.current.beginning_of_month..Date.current.end_of_month)
    end
  end

  def calculate_summary
    total_deliveries = @deliveries.count
    total_customers = @deliveries.distinct.count(:customer_id)
    total_amount = @deliveries.sum(:final_amount_after_discount)
    completed_deliveries = @deliveries.where(status: 'completed').count
    
    completion_rate = total_deliveries > 0 ? ((completed_deliveries.to_f / total_deliveries) * 100).round(1) : 0
    
    {
      total_deliveries: total_deliveries,
      total_customers: total_customers,
      total_amount: total_amount,
      completion_rate: completion_rate,
      completed_deliveries: completed_deliveries,
      pending_deliveries: @deliveries.where(status: 'pending').count,
      cancelled_deliveries: @deliveries.where(status: 'cancelled').count
    }
  end

  def deliveries_json
    @deliveries.map do |delivery|
      {
        id: delivery.id,
        date: delivery.scheduled_date.strftime('%b %d, %Y'),
        customer_name: delivery.customer.name,
        customer_phone: delivery.customer.phone,
        customer_member_id: delivery.customer.member_id,
        product: delivery.product.name,
        quantity: "#{delivery.quantity} #{delivery.unit}",
        amount: delivery.final_amount_after_discount || 0,
        status: delivery.status,
        delivery_person: delivery.delivery_person&.name || 'Not Assigned',
        special_instructions: delivery.special_instructions
      }
    end
  end
end