class CustomerPatternsController < ApplicationController
  before_action :require_login

  def index
    @current_month = params[:month]&.to_i || Date.current.month
    @current_year = params[:year]&.to_i || Date.current.year
    @delivery_person_id = params[:delivery_person_id].presence
    @customer_id = params[:customer_id].presence
    @pattern_filter = params[:pattern].presence
    @customer_name = params[:customer_name].presence
    @page = params[:page]&.to_i || 1
    @per_page = params[:per_page]&.to_i || 60

    # Cache key for this specific request with timestamp for real-time updates
    cache_timestamp = Time.current.to_i / 30 # Changes every 30 seconds
    cache_key = "customer_patterns_#{@current_month}_#{@current_year}_#{@delivery_person_id}_#{@customer_id}_#{@pattern_filter}_#{@customer_name}_#{@page}_#{@per_page}_#{cache_timestamp}"

    # Try to get from cache first
    cached_data = Rails.cache.read(cache_key)
    if cached_data
      @delivery_people = cached_data[:delivery_people]
      @customers = cached_data[:customers]
      @total_customers = cached_data[:total_customers]
      @regular_count = cached_data[:regular_count]
        @irregular_count = cached_data[:irregular_count]
      @customer_patterns = cached_data[:customer_patterns]
      @total_count = cached_data[:total_count]
      @total_pages = cached_data[:total_pages]
      @has_next_page = cached_data[:has_next_page]
      @has_prev_page = cached_data[:has_prev_page]
      @month_name = cached_data[:month_name]
      return
    end

    # Get all delivery people for the dropdown (cached separately)
    @delivery_people = Rails.cache.fetch("delivery_people_list", expires_in: 1.hour) do
      User.where(role: 'delivery_person').select(:id, :name).order(:name)
    end

    # Get all customers for the dropdown (cached separately)
    @customers = Rails.cache.fetch("customers_list", expires_in: 1.hour) do
      Customer.where(is_active: true).select(:id, :name, :phone_number, :member_id).order(:name)
    end

    start_date = Date.new(@current_year, @current_month, 1).beginning_of_month
    end_date = start_date.end_of_month

    # Use optimized database query with CTEs and window functions
    result = execute_optimized_patterns_query(start_date, end_date, @delivery_person_id, @customer_id, @pattern_filter, @customer_name, @page, @per_page)

    @total_customers = result[:total_customers]
    @regular_count = result[:regular_count]
    @irregular_count = result[:irregular_count]
    @customer_patterns = result[:customer_patterns]
    @total_count = result[:total_count]
    @total_pages = result[:total_pages]
    @has_next_page = result[:has_next_page]
    @has_prev_page = result[:has_prev_page]
    @month_name = Date.new(@current_year, @current_month, 1).strftime("%B %Y")

    # Cache the results for 30 seconds to ensure near real-time updates
    cache_data = {
      delivery_people: @delivery_people,
      customers: @customers,
      total_customers: @total_customers,
      regular_count: @regular_count,
      irregular_count: @irregular_count,
      customer_patterns: @customer_patterns,
      total_count: @total_count,
      total_pages: @total_pages,
      has_next_page: @has_next_page,
      has_prev_page: @has_prev_page,
      month_name: @month_name
    }
    Rails.cache.write(cache_key, cache_data, expires_in: 30.seconds)
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
    # Calculate separate pending counts for button display
    @pending_till_today_count = @delivery_assignments
      .where(status: 'pending').where(customer_id: @customer.id)
      .where(scheduled_date: start_date..Date.current)
      .count

    @pending_till_month_end_count = @delivery_assignments
      .where(status: 'pending').where(customer_id: @customer.id)
      .where(scheduled_date: start_date..end_date)
      .count

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

    completed_count = 0
    assignments_to_complete.each do |assignment|

      if assignment.update(status: 'completed', completed_at: Time.current, booked_by: 0)
        completed_count += 1
      end
    end

    clear_customer_patterns_cache if completed_count > 0
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

  def complete_all
    @customer = Customer.find(params[:customer_id])
    month = params[:month]&.to_i || Date.current.month
    year = params[:year]&.to_i || Date.current.year

    start_date = Date.new(year, month, 1).beginning_of_month
    end_date = start_date.end_of_month

    # Find ALL pending assignments for this customer in the selected month
    assignments_to_complete = DeliveryAssignment
      .where(customer_id: @customer.id)
      .where(status: 'pending')
      .where(scheduled_date: start_date..end_date)

    completed_count = 0
    assignments_to_complete.each do |assignment|
      if assignment.update(status: 'completed', completed_at: Time.current, booked_by: 0)
        completed_count += 1
      end
    end

    clear_customer_patterns_cache if completed_count > 0
    respond_to do |format|
      format.json {
        render json: {
          success: true,
          message: "✅ All #{completed_count} pending assignments marked as completed",
          completed_count: completed_count
        }
      }
    end
  rescue => e
    respond_to do |format|
      format.json {
        render json: {
          success: false,
          message: "❌ Error completing all assignments: #{e.message}"
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
    Rails.logger.info "🎯 UPDATE ASSIGNMENT called with params: #{params.inspect}"
    Rails.logger.info "🔍 Raw request params: #{request.parameters.inspect}"
    Rails.logger.info "🔍 Delivery assignment params: #{params[:delivery_assignment].inspect}"

    @assignment = DeliveryAssignment.find(params[:id])
    Rails.logger.info "📋 Found assignment: #{@assignment.id}, current quantity: #{@assignment.quantity}, unit: #{@assignment.unit}"

    begin
      parsed_params = assignment_params
      Rails.logger.info "🔄 Parsed assignment params: #{parsed_params.inspect}"
    rescue => e
      Rails.logger.error "❌ Error parsing assignment params: #{e.message}"
      Rails.logger.error "Available params keys: #{params.keys.inspect}"
      raise e
    end

    if @assignment.update(parsed_params)
      # Recalculate final amount if quantity or discount changed
      if @assignment.product.present?
        base_amount = @assignment.product.price * @assignment.quantity
        discount_amount = @assignment.discount_amount || 0
        final_amount = [base_amount - discount_amount, 0].max
        @assignment.update_column(:final_amount_after_discount, final_amount)
      end

      clear_customer_patterns_cache
      respond_to do |format|
        format.json {
          render json: {
            success: true,
            message: "✅ Assignment updated successfully",
            assignment: {
              id: @assignment.id,
              quantity: @assignment.quantity,
              unit: @assignment.unit,
              discount_amount: @assignment.discount_amount,
              final_amount_after_discount: @assignment.final_amount_after_discount
            }
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
      clear_customer_patterns_cache
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
    Rails.logger.info "🎯 COMPLETE_ALL_TILL_TODAY called with params: #{params.inspect}"
    customer_id = params[:customer_id]
    month = params[:month]&.to_i || Date.current.month
    year = params[:year]&.to_i || Date.current.year
    delivery_person_id = params[:delivery_person_id].presence

    # Use current month boundaries for filtering
    start_date = Date.current.beginning_of_month
    end_date = Date.current.end_of_month
    Rails.logger.info "🗓️ Date range: #{start_date} to #{Date.current} (current month till today)"

    # Find all pending assignments till today for the specific customer in current month
    query = DeliveryAssignment
      .where(status: 'pending')
      .where(scheduled_date: start_date..Date.current)

    # Filter by specific customer
    if customer_id.present?
      query = query.where(customer_id: customer_id)
    end

    if delivery_person_id.present?
      query = query.where(user_id: delivery_person_id)
    end

    assignments_to_complete = query.includes(:customer, :user)

    completed_count = 0
    customers_affected = []
    delivery_people_affected = []

    assignments_to_complete.each do |assignment|
      if assignment.update(status: 'completed', completed_at: Time.current, booked_by: 0)
        completed_count += 1
        customers_affected << assignment.customer.name unless customers_affected.include?(assignment.customer.name)
        delivery_people_affected << assignment.user.name unless delivery_people_affected.include?(assignment.user.name)
      end
    end

    clear_customer_patterns_cache if completed_count > 0
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
    clear_customer_patterns_cache if deleted_count > 0

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

  def clear_cache
    clear_customer_patterns_cache
    respond_to do |format|
      format.json {
        render json: {
          success: true,
          message: "🧹 Cache cleared successfully"
        }
      }
    end
  end

  def get_products
    begin
      # Get all products for the modal dropdown
      @products = Rails.cache.fetch("products_list_v2", expires_in: 1.hour) do
        Product.where(is_active: true).select(:id, :name, :unit_type, :price).order(:name).to_a
      end

      render json: {
        success: true,
        products: @products.map { |p| {
          id: p.id,
          name: p.name,
          unit_type: p.unit_type || 'units',
          price: p.price || 0
        } }
      }
    rescue => e
      Rails.logger.error "Error in get_products: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      render json: {
        success: false,
        error: e.message,
        products: []
      }, status: 500
    end
  end

  def get_delivery_people
    begin
      # Get all delivery people for the modal dropdown
      @delivery_people = Rails.cache.fetch("delivery_people_list_v2", expires_in: 1.hour) do
        User.where(role: 'delivery_person').select(:id, :name).order(:name).to_a
      end

      render json: {
        success: true,
        delivery_people: @delivery_people.map { |dp| {
          id: dp.id,
          name: dp.name
        } }
      }
    rescue => e
      Rails.logger.error "Error in get_delivery_people: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      render json: {
        success: false,
        error: e.message,
        delivery_people: []
      }, status: 500
    end
  end

  def search_customers
    # Support both 'q' (Select2 format) and 'query' (legacy format) parameters
    query = (params[:q] || params[:query])&.strip
    load_all = params[:load_all] == 'true'

    if load_all || (query.present? && query.length >= 0)
      cache_key = load_all ? "all_customers_list" : "customer_search_#{query.downcase}"

      customers = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        if load_all
          # Load all active customers for initial display
          Customer.where(is_active: true)
                 .select(:id, :name)
                 .order(:name)
                 .to_a
        else
          # Search with query
          Customer.where(is_active: true)
                 .where("name ILIKE ?", "#{query}%")
                 .select(:id, :name)
                 .order(:name)
                 .limit(50)
                 .to_a
        end
      end

      # Format for our custom dropdown
      results = customers.map { |c| { id: c.id, text: c.name } }

      render json: {
        results: results,
        pagination: { more: false },
        query: query,
        total: customers.length
      }
    else
      render json: { results: [], pagination: { more: false } }
    end
  rescue => e
    Rails.logger.error "Error in search_customers: #{e.message}"
    render json: { results: [], pagination: { more: false } }, status: 500
  end

  def get_assignment_summary
    begin
      @customer = Customer.find(params[:customer_id])
      month = params[:month]&.to_i || Date.current.month
      year = params[:year]&.to_i || Date.current.year

      start_date = Date.new(year, month, 1).beginning_of_month
      end_date = start_date.end_of_month

      # Get current assignments summary
      assignments = DeliveryAssignment
        .where(customer_id: @customer.id)
        .where(status: 'pending')
        .where(scheduled_date: start_date..end_date)

      total_count = assignments.count
      current_quantity = assignments.sum(:quantity)
      earliest_date = assignments.minimum(:scheduled_date)
      latest_date = assignments.maximum(:scheduled_date)

      render json: {
        success: true,
        summary: {
          total_assignments: total_count,
          current_total_quantity: current_quantity.round(2),
          date_range: total_count > 0 ? "#{earliest_date&.strftime('%d %b')} - #{latest_date&.strftime('%d %b')}" : "No assignments"
        }
      }
    rescue => e
      Rails.logger.error "Error in get_assignment_summary: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      render json: {
        success: false,
        error: e.message,
        summary: {
          total_assignments: 0,
          current_total_quantity: 0,
          date_range: "Error loading"
        }
      }, status: 500
    end
  end

  def bulk_edit_assignments
    @customer = Customer.find(params[:customer_id])
    month = params[:month]&.to_i || Date.current.month
    year = params[:year]&.to_i || Date.current.year
    new_quantity = params[:quantity]&.to_f
    new_unit = params[:unit].presence || 'liters'

    start_date = Date.new(year, month, 1).beginning_of_month
    end_date = start_date.end_of_month

    # Verify eligibility before proceeding
    unless check_bulk_edit_eligibility(@customer.id, start_date, end_date)
      respond_to do |format|
        format.json {
          render json: {
            success: false,
            message: "❌ Bulk edit not allowed. Customer must have assignments for all days with same quantity."
          }
        }
      end
      return
    end

    # Find all pending assignments for this customer in the selected month
    assignments_to_update = DeliveryAssignment
      .where(customer_id: @customer.id)
      .where(status: 'pending')
      .where(scheduled_date: start_date..end_date)

    updated_count = 0
    total_assignments = assignments_to_update.count
    errors = []

    DeliveryAssignment.transaction do
      assignments_to_update.find_each do |assignment|
        begin
          update_attrs = {
            quantity: new_quantity,
            unit: new_unit
          }

          if assignment.update(update_attrs)
            # Always recalculate final amount after updating quantity/unit
            if assignment.product.present?
              # Calculate the new final amount based on product price and new quantity
              base_amount = assignment.product.price * new_quantity
              discount_amount = assignment.discount_amount || 0
              assignment.update_column(:final_amount_after_discount, base_amount - discount_amount)
            end
            updated_count += 1
          else
            errors << "Assignment #{assignment.id}: #{assignment.errors.full_messages.join(', ')}"
          end
        rescue => e
          errors << "Assignment #{assignment.id}: #{e.message}"
        end
      end

      # Rollback if too many errors
      if errors.size > total_assignments * 0.1 # Allow up to 10% failures
        raise "Too many assignment update failures: #{errors.size}/#{total_assignments}"
      end
    end

    clear_customer_patterns_cache if updated_count > 0

    respond_to do |format|
      format.json {
        render json: {
          success: true,
          message: "✅ Successfully updated #{updated_count} assignments for #{@customer.name} in #{Date::MONTHNAMES[month]} #{year}",
          updated_count: updated_count,
          total_assignments: total_assignments,
          customer_name: @customer.name,
          month_name: Date::MONTHNAMES[month],
          year: year,
          errors: errors.first(5) # Return first 5 errors if any
        }
      }
    end
  rescue => e
    Rails.logger.error "Error in bulk_edit_assignments: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    respond_to do |format|
      format.json {
        render json: {
          success: false,
          message: "❌ Error updating assignments: #{e.message}",
          errors: errors
        }, status: 500
      }
    end
  end

  def update_pattern
    @customer = Customer.find(params[:customer_id])
    month = params[:target_month]&.to_i || params[:month]&.to_i || Date.current.month
    year = params[:target_year]&.to_i || params[:year]&.to_i || Date.current.year
    scheduled_quantity = params[:scheduled_quantity]&.to_f || 0
    unit = params[:unit].presence || 'liters'

    start_date = Date.new(year, month, 1).beginning_of_month
    end_date = start_date.end_of_month

    # Find all pending assignments for this customer in the selected month
    assignments_to_update = DeliveryAssignment
      .where(customer_id: @customer.id)
      .where(status: 'pending')
      .where(scheduled_date: start_date..end_date)

    updated_count = 0
    total_assignments = assignments_to_update.count
    errors = []

    DeliveryAssignment.transaction do
      assignments_to_update.find_each do |assignment|
        begin
          update_attrs = {
            quantity: scheduled_quantity,
            unit: unit
          }

          if assignment.update(update_attrs)
            # Always recalculate final amount after updating quantity/unit
            if assignment.product.present?
              # Calculate the new final amount based on product price and new quantity
              base_amount = assignment.product.price * scheduled_quantity
              discount_amount = assignment.discount_amount || 0
              assignment.update_column(:final_amount_after_discount, base_amount - discount_amount)
            end
            updated_count += 1
          else
            errors << "Assignment #{assignment.id}: #{assignment.errors.full_messages.join(', ')}"
          end
        rescue => e
          errors << "Assignment #{assignment.id}: #{e.message}"
        end
      end

      # Rollback if too many errors
      if errors.size > total_assignments * 0.1 # Allow up to 10% failures
        raise "Too many assignment update failures: #{errors.size}/#{total_assignments}"
      end
    end

    clear_customer_patterns_cache if updated_count > 0

    respond_to do |format|
      format.json {
        render json: {
          success: true,
          message: "🎯 Successfully updated #{updated_count}/#{total_assignments} delivery assignments for #{@customer.name} in #{Date::MONTHNAMES[month]} #{year}",
          updated_count: updated_count,
          total_assignments: total_assignments,
          customer_name: @customer.name,
          month_name: Date::MONTHNAMES[month],
          year: year,
          errors: errors.first(5), # Return first 5 errors if any
          delivery_person_updated: delivery_person_id.present?
        }
      }
    end
  rescue => e
    Rails.logger.error "Error in update_pattern: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    respond_to do |format|
      format.json {
        render json: {
          success: false,
          message: "❌ Error updating pattern: #{e.message}",
          errors: errors
        }, status: 500
      }
    end
  end

  private

  def assignment_params
    params.require(:delivery_assignment).permit(:quantity, :unit, :discount_amount, :status, :scheduled_date)
  end

  # Check if customer is eligible for bulk edit
  # Requirements: All days in month have assignments with same quantity
  def check_bulk_edit_eligibility(customer_id, start_date, end_date)
    days_in_month = end_date.day

    # Check ALL assignments to determine if the customer has a consistent pattern
    all_assignments = DeliveryAssignment.where(
      customer_id: customer_id,
      scheduled_date: start_date..end_date
    ).pluck(:scheduled_date, :quantity)

    # For regular customers: Must have assignments for at least 20 days of month (more permissive)
    min_required_days = [20, (days_in_month * 0.7).to_i].max
    return false unless all_assignments.length >= min_required_days

    # All assignments must have the same quantity (if they exist)
    if all_assignments.any?
      quantities = all_assignments.map(&:last).uniq
      return false unless quantities.length == 1
      # Must have a valid quantity greater than 0
      return false unless quantities.first > 0
    end

    # Check if there are any pending assignments to edit
    # (We need at least some pending assignments to make editing worthwhile)
    pending_assignments_count = DeliveryAssignment.where(
      customer_id: customer_id,
      scheduled_date: start_date..end_date,
      status: 'pending'
    ).count

    # Allow editing if there are pending assignments (more permissive - just need 1+)
    return false unless pending_assignments_count > 0

    true
  rescue => e
    Rails.logger.error "Error checking bulk edit eligibility for customer #{customer_id}: #{e.message}"
    false
  end

  def clear_customer_patterns_cache
    # Clear all customer patterns cache keys that might be affected
    Rails.cache.delete_matched("customer_patterns_*")
  end

  # Optimized query with database-level pagination and heavy caching
  def execute_optimized_patterns_query(start_date, end_date, delivery_person_id, customer_id, pattern_filter, customer_name, page, per_page)
    days_in_month = end_date.day

    # Create a comprehensive cache key with timestamp for better cache invalidation
    cache_timestamp = Time.current.to_i / 60 # Changes every minute
    cache_key = "customer_patterns_optimized_#{start_date}_#{end_date}_#{delivery_person_id}_#{customer_id}_#{pattern_filter}_#{customer_name}_#{page}_#{per_page}_v4_#{cache_timestamp}"

    Rails.cache.fetch(cache_key, expires_in: 1.minute) do
      # Use the original optimized SQL but with LIMIT/OFFSET for real pagination
      sql = <<~SQL
        WITH customer_delivery_stats AS (
          SELECT
            c.id as customer_id,
            c.name as customer_name,
            u.name as delivery_person_name,
            c.delivery_person_id,
            COUNT(DISTINCT DATE(da.scheduled_date)) as days_delivered,
            COUNT(da.id) as total_assignments,
            COALESCE(SUM(CASE WHEN p.unit_type = 'liters' THEN da.quantity ELSE 0 END), 0) as total_liters,
            COALESCE(SUM(da.final_amount_after_discount), 0) as estimated_amount,
            -- Get most common scheduled quantity for regular customers
            (SELECT da2.quantity
             FROM delivery_assignments da2
             WHERE da2.customer_id = c.id
               AND da2.scheduled_date BETWEEN $3 AND $4
               AND da2.status = 'pending'
             GROUP BY da2.quantity
             ORDER BY COUNT(*) DESC
             LIMIT 1) as scheduled_quantity,
            -- Get most common product name for scheduled assignments
            (SELECT p2.name
             FROM delivery_assignments da2
             JOIN products p2 ON da2.product_id = p2.id
             WHERE da2.customer_id = c.id
               AND da2.scheduled_date BETWEEN $3 AND $4
               AND da2.status = 'pending'
             GROUP BY p2.name, da2.product_id
             ORDER BY COUNT(*) DESC
             LIMIT 1) as scheduled_product
          FROM customers c
          LEFT JOIN users u ON c.delivery_person_id = u.id
          LEFT JOIN delivery_assignments da ON c.id = da.customer_id
            AND da.scheduled_date BETWEEN $3 AND $4
          LEFT JOIN products p ON da.product_id = p.id
          WHERE c.is_active = true
            #{delivery_person_id.present? ? 'AND c.delivery_person_id = $5' : ''}
            #{customer_id.present? ? "AND c.id = $#{delivery_person_id.present? ? '6' : '5'}" : ''}
            #{customer_name.present? ? "AND c.name ILIKE $#{5 + [delivery_person_id, customer_id].compact.size}" : ''}
          GROUP BY c.id, c.name, u.name, c.delivery_person_id
        ),
        customer_patterns AS (
          SELECT *,
            CASE
              WHEN days_delivered >= #{(days_in_month * 0.9).to_i} AND total_liters >= 0.5 THEN 'regular'
              ELSE 'irregular'
            END as pattern
          FROM customer_delivery_stats
        ),
        pattern_counts AS (
          SELECT
            COUNT(*) as total_customers,
            COUNT(*) FILTER (WHERE pattern = 'regular') as regular_count,
            COUNT(*) FILTER (WHERE pattern = 'irregular') as irregular_count
          FROM customer_patterns
        ),
        filtered_patterns AS (
          SELECT * FROM customer_patterns
          #{pattern_filter.present? ? "WHERE pattern = $#{5 + [delivery_person_id, customer_id, customer_name].compact.size}" : ''}
          ORDER BY customer_name
        )
        SELECT
          fp.customer_id,
          fp.customer_name,
          fp.delivery_person_name,
          fp.days_delivered,
          fp.total_assignments,
          fp.total_liters,
          fp.estimated_amount,
          fp.pattern,
          fp.scheduled_quantity,
          fp.scheduled_product,
          pc.total_customers,
          pc.regular_count,
          pc.irregular_count,
          COUNT(*) OVER() as total_filtered_count
        FROM filtered_patterns fp
        CROSS JOIN pattern_counts pc
        LIMIT $1 OFFSET $2
      SQL

      # Prepare parameters
      params = [per_page, (page - 1) * per_page, start_date, end_date]
      params << delivery_person_id if delivery_person_id.present?
      params << customer_id if customer_id.present?
      params << "%#{customer_name}%" if customer_name.present?
      params << pattern_filter if pattern_filter.present?

      # Execute the query
      results = ActiveRecord::Base.connection.exec_query(sql, 'customer_patterns_fast', params)

      # Process results quickly without expensive operations
      customer_patterns = results.rows.map do |row|
        days_delivered = row[3].to_i
        pattern = row[7]

        # Simple pattern description
        pattern_description = case pattern
                              when 'regular' then 'Every day'
                              else "Irregular (#{days_delivered}/#{days_in_month} days)"
                              end

        {
          customer: OpenStruct.new(
            id: row[0],
            name: row[1],
            to_param: row[0].to_s  # This is needed for Rails path helpers
          ),
          delivery_person_name: row[2] || "Not Assigned",
          total_liters: row[5].to_f.round(2),
          primary_product: nil, # Skip expensive lookup
          delivery_days: [], # Skip expensive lookup
          days_delivered: days_delivered,
          estimated_amount: row[6].to_f.round(2),
          pattern: pattern,
          pattern_description: pattern_description,
          total_assignments: row[4].to_i,
          scheduled_quantity: row[8]&.to_f&.round(2),
          scheduled_product: row[9],
          can_bulk_edit: check_bulk_edit_eligibility(row[0], start_date, end_date)
        }
      end

      # Get counts from first row or set defaults
      if results.rows.any?
        first_row = results.rows.first
        total_customers = first_row[10].to_i
        regular_count = first_row[11].to_i
        irregular_count = first_row[12].to_i
        total_filtered_count = first_row[13].to_i
      else
        total_customers = 0
        regular_count = 0
        irregular_count = 0
        total_filtered_count = 0
      end

      total_pages = (total_filtered_count.to_f / per_page).ceil
      has_next_page = page < total_pages
      has_prev_page = page > 1

      {
        customer_patterns: customer_patterns,
        total_customers: total_customers,
        regular_count: regular_count,
        irregular_count: irregular_count,
        total_count: total_filtered_count,
        total_pages: total_pages,
        has_next_page: has_next_page,
        has_prev_page: has_prev_page
      }
    end
  end

  def calculate_customer_patterns(customer_query, delivery_data_by_customer, start_date, end_date)
    days_in_month = end_date.day

    customer_query.find_each.map do |customer|
      deliveries = delivery_data_by_customer[customer.id] || []

      # Calculate metrics from the deliveries
      delivery_days = deliveries.map { |d| d.scheduled_date.day }.uniq.sort

      # Calculate total liters from ALL delivery statuses
      total_liters = deliveries
        .select { |d| d.product_unit_type == 'liters' }
        .sum(&:quantity)

      # Calculate estimated amount (sum of final_amount_after_discount)
      estimated_amount = deliveries.sum do |delivery|
        delivery.final_amount_after_discount.to_f || 0
      end

      # Find primary product (most frequent)
      primary_product = if deliveries.any?
        product_counts = deliveries.group_by(&:product_id)
          .transform_values(&:count)
        most_frequent_product_id = product_counts.max_by { |_, count| count }.first
        Product.find(most_frequent_product_id) if most_frequent_product_id
      else
        nil
      end

      # Determine customer pattern
      pattern = determine_customer_pattern(delivery_days, days_in_month, total_liters)

      {
        customer: customer,
        delivery_person_name: customer.delivery_person&.name || "Not Assigned",
        total_liters: total_liters.round(2),
        primary_product: primary_product,
        delivery_days: delivery_days,
        days_delivered: delivery_days.length,
        estimated_amount: estimated_amount.round(2),
        pattern: pattern,
        pattern_description: get_pattern_description(delivery_days, days_in_month),
        deliveries: deliveries,
        total_assignments: deliveries.length
      }
    end
  end

  def determine_customer_pattern(delivery_days, days_in_month, total_liters)
    return 'irregular' if delivery_days.empty?

    # Regular: delivered every day and at least 0.5 liters total
    if delivery_days.length >= (days_in_month * 0.9) && total_liters >= 0.5
      'regular'
    else
      'irregular'
    end
  end

  def get_pattern_description(delivery_days, days_in_month)
    return 'No deliveries' if delivery_days.empty?

    if delivery_days.length >= (days_in_month * 0.9)
      'Every day'
    else
      "Days: #{delivery_days.join(', ')}"
    end
  end
end
