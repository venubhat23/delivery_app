class MilkAnalyticsController < ApplicationController
  before_action :authenticate_user!

  def index
    # Handle dashboard filters - Default to current month (1st to end of current month)
    @product_id = params[:product_id]
    @date_range = params[:date_range] || 'monthly'
    
    case @date_range
    when 'today'
      @start_date = Date.current
      @end_date = Date.current
    when 'yesterday'
      @start_date = 1.day.ago.to_date
      @end_date = 1.day.ago.to_date
    when 'weekly'
      @start_date = Date.current.beginning_of_week
      @end_date = Date.current.end_of_week
    when 'monthly'
      # Default: Current Month (1st to end of current month)
      @start_date = Date.current.beginning_of_month
      @end_date = Date.current.end_of_month
    when 'last_month'
      @start_date = 1.month.ago.beginning_of_month
      @end_date = 1.month.ago.end_of_month
    when 'custom'
      @start_date = params[:from_date].present? ? Date.parse(params[:from_date]) : Date.current.beginning_of_month
      @end_date = params[:to_date].present? ? Date.parse(params[:to_date]) : Date.current.end_of_month
    else
      # Default fallback: Current Month
      @start_date = Date.current.beginning_of_month
      @end_date = Date.current.end_of_month
    end
    
    # Always calculate dashboard statistics
    calculate_dashboard_stats
    # Always calculate summaries for tables
    calculate_summaries
    # Always prepare daily calculations so the Daily Report tab has data ready
    calculate_daily_calculations
    # Get procurement schedules for the schedules table
    get_procurement_schedules
    
    respond_to do |format|
      format.html
      format.json do
        render json: {
          total_vendors: @total_vendors,
          total_liters: @total_liters,
          total_cost: @total_cost,
          total_delivered: @total_delivered,
          total_revenue: @total_revenue,
          total_profit: @total_profit
        }
      end
    end
  end

  def calendar_view
    # Parse date with error handling
    begin
      @date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    rescue Date::Error
      @date = Date.current
    end
    
    @view_type = params[:view_type] || 'month' # Default to monthly, but allow user selection
    
    # Set date range based on view type
    case @view_type
    when 'week'
      @start_date = @date.beginning_of_week
      @end_date = @date.end_of_week
    when 'today'
      @start_date = @date
      @end_date = @date
    when 'custom'
      # Use custom date range if provided, with error handling
      begin
        @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current.beginning_of_month
      rescue Date::Error
        @start_date = Date.current.beginning_of_month
      end
      
      begin
        @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current.end_of_month
      rescue Date::Error
        @end_date = Date.current.end_of_month
      end
      
      # Ensure start_date is not after end_date
      if @start_date > @end_date
        @start_date = @end_date
      end
    else # 'month'
      @start_date = @date.beginning_of_month
      @end_date = @date.end_of_month
    end
    
    # Debug info (remove in production)
    Rails.logger.info "Calendar View Debug: User ID: #{current_user&.id}, Date Range: #{@start_date} to #{@end_date}"
    
    # Get assignments for the date range with optimized includes to avoid N+1 queries
    if current_user
      @assignments = current_user.procurement_assignments
                                .for_date_range(@start_date, @end_date)
                                .includes(:procurement_schedule, :product)
                                .preload(:procurement_schedule, :product)
                                .order(:date, :created_at)
    else
      # Fallback for demo - get first user's assignments if no current user
      first_user = User.first
      @assignments = first_user&.procurement_assignments
                               &.for_date_range(@start_date, @end_date)
                               &.includes(:procurement_schedule, :product)
                               &.preload(:procurement_schedule, :product)
                               &.order(:date, :created_at) || []
    end
    
    # Apply vendor filter if specified
    if params[:vendor_filter].present?
      @assignments = @assignments.where(vendor_name: params[:vendor_filter])
    end
    
    Rails.logger.info "Calendar View Debug: Found #{@assignments.count} assignments"
    
    # Group by date for calendar display - maintain chronological order
    @assignments_by_date = @assignments.group_by(&:date).sort_by { |date, _| date }
    
    # Daily summaries with improved calculations
    @daily_summaries = (@start_date..@end_date).map do |date|
      daily_assignments = @assignments.select { |a| a.date == date }
      
      # Calculate totals including both actual and planned data
      total_planned = daily_assignments.sum(&:planned_quantity)
      total_actual = daily_assignments.sum { |a| a.actual_quantity || 0 }
      
      # For cost and revenue, use actual if available, otherwise use planned
      total_cost = daily_assignments.sum do |a|
        if a.actual_quantity.present?
          a.actual_cost
        else
          a.planned_cost
        end
      end
      
      total_revenue = daily_assignments.sum do |a|
        if a.actual_quantity.present?
          a.actual_revenue
        else
          a.planned_revenue
        end
      end
      
      profit = total_revenue - total_cost
      
      {
        date: date,
        total_planned: total_planned,
        total_actual: total_actual,
        total_cost: total_cost,
        total_revenue: total_revenue,
        profit: profit,
        assignments_count: daily_assignments.count,
        completed_count: daily_assignments.count { |a| a.is_completed? }
      }
    end
    
    # Use a minimal layout without sidebar for iframe loading
    render layout: 'public'
  end

  def vendor_analysis
    @vendor = params[:vendor]
    @date_range = params[:date_range] || 'month'
    @from_date = params[:from_date]
    @to_date = params[:to_date]
    
    # Use custom date range if provided, otherwise use predefined range
    if @from_date.present? && @to_date.present?
      @start_date = Date.parse(@from_date)
      @end_date = Date.parse(@to_date)
      @date_range = 'custom'
    else
      @start_date, @end_date = calculate_date_range(@date_range)
    end
    
    if @vendor.present?
      # Specific vendor analysis with optimized includes
      @vendor_assignments = current_user.procurement_assignments
                                       .for_vendor(@vendor)
                                       .for_date_range(@start_date, @end_date)
                                       .includes(:product, :procurement_schedule)
                                       .preload(:product, :procurement_schedule)
      
      @vendor_analytics = {
        total_assignments: @vendor_assignments.count,
        completed_assignments: @vendor_assignments.completed.count,
        completion_rate: @vendor_assignments.empty? ? 0 : (@vendor_assignments.completed.count.to_f / @vendor_assignments.count * 100).round(2),
        total_planned_quantity: @vendor_assignments.sum(:planned_quantity),
        total_actual_quantity: @vendor_assignments.sum(:actual_quantity),
        total_cost: @vendor_assignments.sum(&:actual_cost),
        total_revenue: @vendor_assignments.sum(&:actual_revenue),
        profit: @vendor_assignments.sum(&:actual_profit),
        average_daily_quantity: @vendor_assignments.with_actual_quantity.average(:actual_quantity)&.round(2) || 0
      }
      
      # Daily trend for this vendor
      @vendor_daily_data = generate_vendor_daily_data(@vendor, @start_date, @end_date)
    else
      # All vendors comparison
      @all_vendors = current_user.procurement_assignments
                                .for_date_range(@start_date, @end_date)
                                .group(:vendor_name)
                                .group_by(&:vendor_name)
                                .map do |vendor, assignments|
        {
          vendor: vendor,
          total_assignments: assignments.count,
          completed_assignments: assignments.count { |a| a.is_completed? },
          completion_rate: assignments.empty? ? 0 : (assignments.count { |a| a.is_completed? }.to_f / assignments.count * 100).round(2),
          total_quantity: assignments.sum { |a| a.actual_quantity || 0 },
          total_cost: assignments.sum(&:actual_cost),
          profit: assignments.sum(&:actual_profit),
          average_price: assignments.empty? ? 0 : (assignments.sum(&:buying_price) / assignments.count).round(2)
        }
      end
    end
    
    # Available vendors for dropdown
    @vendors = current_user.procurement_assignments.distinct.pluck(:vendor_name).compact.sort
  end

  def profit_analysis
    @date_range = params[:date_range] || 'month'
    @from_date = params[:from_date]
    @to_date = params[:to_date]
    
    # Use custom date range if provided, otherwise use predefined range
    if @from_date.present? && @to_date.present?
      @start_date = Date.parse(@from_date)
      @end_date = Date.parse(@to_date)
      @date_range = 'custom'
    else
      @start_date, @end_date = calculate_date_range(@date_range)
    end
    
    assignments = current_user.procurement_assignments.for_date_range(@start_date, @end_date)
    
    # Enhanced profit breakdown including both actual and planned data
    total_cost = assignments.sum do |a|
      if a.actual_quantity.present?
        a.actual_cost
      else
        a.planned_cost
      end
    end
    
    total_revenue = assignments.sum do |a|
      if a.actual_quantity.present?
        a.actual_revenue
      else
        a.planned_revenue
      end
    end
    
    gross_profit = total_revenue - total_cost
    profit_margin = total_revenue > 0 ? (gross_profit / total_revenue * 100).round(2) : 0
    
    @profit_analysis = {
      total_cost: total_cost,
      total_revenue: total_revenue,
      gross_profit: gross_profit,
      profit_margin: profit_margin,
      daily_profits: [],
      vendor_profits: []
    }
    
    # Daily profit trend with improved calculations
    @profit_analysis[:daily_profits] = (@start_date..@end_date).map do |date|
      daily_assignments = assignments.select { |a| a.date == date }
      
      daily_cost = daily_assignments.sum do |a|
        if a.actual_quantity.present?
          a.actual_cost
        else
          a.planned_cost
        end
      end
      
      daily_revenue = daily_assignments.sum do |a|
        if a.actual_quantity.present?
          a.actual_revenue
        else
          a.planned_revenue
        end
      end
      
      {
        date: date.strftime('%Y-%m-%d'),
        cost: daily_cost,
        revenue: daily_revenue,
        profit: daily_revenue - daily_cost
      }
    end
    
    # Vendor profit breakdown with improved calculations
    @profit_analysis[:vendor_profits] = assignments.group_by(&:vendor_name).map do |vendor, vendor_assignments|
      vendor_cost = vendor_assignments.sum do |a|
        if a.actual_quantity.present?
          a.actual_cost
        else
          a.planned_cost
        end
      end
      
      vendor_revenue = vendor_assignments.sum do |a|
        if a.actual_quantity.present?
          a.actual_revenue
        else
          a.planned_revenue
        end
      end
      
      vendor_profit = vendor_revenue - vendor_cost
      
      {
        vendor: vendor,
        cost: vendor_cost,
        revenue: vendor_revenue,
        profit: vendor_profit,
        margin: vendor_revenue > 0 ? (vendor_profit / vendor_revenue * 100).round(2) : 0
      }
    end
  end

  def inventory_analysis
    @date = params[:date] ? Date.parse(params[:date]) : Date.current
    
    # Get procurement data (milk purchased)
    procurement_data = current_user.procurement_assignments
                                  .for_date(@date)
                                  .with_actual_quantity
    
    total_purchased = procurement_data.sum(:actual_quantity)
    
    # Get delivery data (milk sold) - assuming milk products
    # Use DeliveryAssignment instead of current_user.delivery_assignments
    delivery_data = DeliveryAssignment
                               .joins(:product)
                               .where(scheduled_date: @date)
                               .where(status: 'completed')
                               .where("products.name ILIKE ? OR products.name ILIKE ?", '%milk%', '%dairy%')
    
    total_delivered = delivery_data.sum(:quantity)
    
    @inventory_data = {
      date: @date,
      total_purchased: total_purchased,
      total_delivered: total_delivered || 0,
      remaining_inventory: total_purchased - (total_delivered || 0),
      utilization_rate: total_purchased > 0 ? ((total_delivered || 0).to_f / total_purchased * 100).round(2) : 0,
      waste_percentage: total_purchased > 0 ? (((total_purchased - (total_delivered || 0)) / total_purchased) * 100).round(2) : 0
    }
    
    # Weekly inventory trend
    week_start = @date.beginning_of_week
    week_end = @date.end_of_week
    
    @weekly_inventory = (week_start..week_end).map do |date|
      daily_purchased = current_user.procurement_assignments
                                   .for_date(date)
                                   .sum(:actual_quantity)
      
      daily_delivered = DeliveryAssignment
                                   .joins(:product)
                                   .where(scheduled_date: date)
                                   .where(status: 'completed')
                                   .where("products.name ILIKE ? OR products.name ILIKE ?", '%milk%', '%dairy%')
                                   .sum(:quantity) || 0
      
      {
        date: date.strftime('%Y-%m-%d'),
        purchased: daily_purchased,
        delivered: daily_delivered,
        remaining: daily_purchased - daily_delivered
      }
    end
  end

  def saved_reports
    @saved_reports = current_user.reports.milk_analytics_reports.recent.limit(50)
    
    respond_to do |format|
      format.json { render json: @saved_reports }
      format.html # saved_reports.html.erb view
    end
  end
  
  def show_report
    @report = current_user.reports.find(params[:id])
    
    respond_to do |format|
      format.json { render json: { report: @report, data: @report.content } }
      format.html # show_report.html.erb view
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.json { render json: { error: 'Report not found' }, status: 404 }
      format.html { 
        flash[:alert] = 'Report not found'
        redirect_to milk_analytics_path 
      }
    end
  end

  # CRUD operations for procurement schedules
  def create_schedule
    @schedule = current_user.procurement_schedules.build(schedule_params)
    
    respond_to do |format|
      if @schedule.save
        format.json { render json: { success: true, message: 'Schedule created successfully', schedule: @schedule } }
      else
        format.json { render json: { success: false, errors: @schedule.errors.full_messages } }
      end
    end
  end

  def update_schedule
    @schedule = current_user.procurement_schedules.find(params[:schedule_id])
    
    respond_to do |format|
      if @schedule.update(schedule_params)
        # Update related procurement assignments if pricing or dates changed
        update_related_assignments(@schedule)
        format.json { render json: { success: true, message: 'Schedule and related assignments updated successfully', schedule: @schedule } }
      else
        format.json { render json: { success: false, errors: @schedule.errors.full_messages } }
      end
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.json { render json: { success: false, error: 'Schedule not found' }, status: 404 }
    end
  end

  def get_schedule
    @schedule = current_user.procurement_schedules.find(params[:schedule_id])
    
    respond_to do |format|
      format.json { render json: { 
        success: true, 
        schedule: {
          id: @schedule.id,
          vendor_name: @schedule.vendor_name,
          product_id: @schedule.product_id,
          from_date: @schedule.from_date.strftime('%Y-%m-%d'),
          to_date: @schedule.to_date.strftime('%Y-%m-%d'),
          quantity: @schedule.quantity,
          buying_price: @schedule.buying_price,
          selling_price: @schedule.selling_price,
          status: @schedule.status,
          unit: @schedule.unit,
          notes: @schedule.notes
        }
      } }
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.json { render json: { success: false, error: 'Schedule not found' }, status: 404 }
    end
  end

  def destroy_schedule
    # Handle schedule_id from params - if sent via JSON, Rails should parse it automatically
    schedule_id = params[:schedule_id]
    
    if schedule_id.blank?
      respond_to do |format|
        format.json { render json: { success: false, error: 'Schedule ID is required' }, status: 400 }
      end
      return
    end
    
    @schedule = current_user.procurement_schedules.find(schedule_id)
    
    # Delete related procurement assignments first
    @schedule.procurement_assignments.destroy_all
    
    respond_to do |format|
      if @schedule.destroy
        format.json { render json: { success: true, message: 'Schedule and related assignments deleted successfully' } }
      else
        format.json { render json: { success: false, error: 'Failed to delete schedule' } }
      end
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.json { render json: { success: false, error: 'Schedule not found' }, status: 404 }
    end
  end

  def generate_reports
    @report_type = params[:report_type] || 'daily_procurement_delivery'
    @from_date = params[:from_date]&.to_date || Date.current.beginning_of_month
    @to_date = params[:to_date]&.to_date || Date.current
    
    begin
      case @report_type
      when 'daily_procurement_delivery'
        @report_data = generate_daily_procurement_delivery_report(@from_date, @to_date)
      when 'vendor_performance'
        @report_data = generate_vendor_performance_report(@from_date, @to_date)
      when 'profit_loss'
        @report_data = generate_profit_loss_report(@from_date, @to_date)
      when 'wastage_analysis'
        @report_data = generate_wastage_analysis_report(@from_date, @to_date)
      when 'monthly_summary'
        @report_data = generate_monthly_summary_report(@from_date, @to_date)
      else
        @report_data = []
      end
      
      # Save report to database
      save_report_to_database(@report_type, @from_date, @to_date, @report_data)
      
      respond_to do |format|
        format.json { render json: { success: true, data: @report_data, message: 'Report generated and saved successfully' } }
        format.html { redirect_to milk_analytics_index_path }
      end
      
    rescue => e
      Rails.logger.error "Error generating report: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      respond_to do |format|
        format.json { render json: { success: false, error: e.message }, status: 500 }
        format.html { 
          flash[:alert] = "Error generating report: #{e.message}"
          redirect_to milk_analytics_index_path 
        }
      end
    end
  end

  private

  def calculate_main_kpis(start_date, end_date)
    assignments = current_user.procurement_assignments.for_date_range(start_date, end_date)
    
    # Calculate total milk purchased (actual + planned for pending)
    actual_quantity = assignments.with_actual_quantity.sum(:actual_quantity)
    pending_planned_quantity = assignments.pending.sum(:planned_quantity)
    total_milk_purchased = actual_quantity + pending_planned_quantity
    
    # Enhanced cost calculations - use actual when available, planned otherwise
    total_cost = assignments.sum do |a|
      if a.actual_quantity.present?
        a.actual_cost
      else
        a.planned_cost
      end
    end
    
    # Enhanced revenue calculations - use actual when available, planned otherwise
    total_revenue = assignments.sum do |a|
      if a.actual_quantity.present?
        a.actual_revenue
      else
        a.planned_revenue
      end
    end
    
    # Calculate gross profit
    gross_profit = total_revenue - total_cost
    
    {
      total_milk_purchased: total_milk_purchased,
      total_cost: total_cost,
      total_revenue: total_revenue,
      gross_profit: gross_profit,
      active_vendors: assignments.distinct.count(:vendor_name),
      completion_rate: assignments.completion_rate_for_period(start_date, end_date),
      average_buying_price: assignments.with_actual_quantity.average(:buying_price)&.round(2) || 0,
      profit_margin: total_cost > 0 ? (gross_profit / total_cost * 100).round(2) : 0
    }
  end

  def calculate_profit_margin(assignments)
    total_cost = assignments.sum(&:actual_cost)
    total_revenue = assignments.sum(&:actual_revenue)
    
    return 0 if total_cost.zero?
    ((total_revenue - total_cost) / total_cost * 100).round(2)
  end

  def calculate_profit_margin_with_planned(assignments)
    # Include both actual and planned data
    actual_cost = assignments.sum(&:actual_cost)
    pending_planned_cost = assignments.pending.sum { |a| a.planned_quantity * a.buying_price }
    total_cost = actual_cost + pending_planned_cost
    
    actual_revenue = assignments.sum(&:actual_revenue)
    pending_planned_revenue = assignments.pending.sum { |a| a.planned_quantity * a.selling_price }
    total_revenue = actual_revenue + pending_planned_revenue
    
    return 0 if total_cost.zero?
    ((total_revenue - total_cost) / total_cost * 100).round(2)
  end

  def generate_daily_chart_data(start_date, end_date)
    assignments = current_user.procurement_assignments.for_date_range(start_date, end_date)
    
    (start_date..end_date).map do |date|
      daily_assignments = assignments.select { |a| a.date == date }
      
      # Enhanced calculations for better chart data
      cost = daily_assignments.sum do |a|
        if a.actual_quantity.present?
          a.actual_cost
        else
          a.planned_cost
        end
      end
      
      revenue = daily_assignments.sum do |a|
        if a.actual_quantity.present?
          a.actual_revenue
        else
          a.planned_revenue
        end
      end
      
      {
        date: date.strftime('%Y-%m-%d'),
        planned_quantity: daily_assignments.sum(&:planned_quantity),
        actual_quantity: daily_assignments.sum { |a| a.actual_quantity || 0 },
        cost: cost,
        revenue: revenue,
        profit: revenue - cost
      }
    end
  end

  def generate_vendor_chart_data(start_date, end_date)
    current_user.procurement_assignments
               .for_date_range(start_date, end_date)
               .group_by(&:vendor_name)
               .map do |vendor, assignments|
      
      # Enhanced vendor calculations
      cost = assignments.sum do |a|
        if a.actual_quantity.present?
          a.actual_cost
        else
          a.planned_cost
        end
      end
      
      revenue = assignments.sum do |a|
        if a.actual_quantity.present?
          a.actual_revenue
        else
          a.planned_revenue
        end
      end
      
      {
        vendor: vendor,
        quantity: assignments.sum { |a| a.actual_quantity || 0 },
        cost: cost,
        revenue: revenue,
        profit: revenue - cost
      }
    end
  end

  def generate_profit_trend_data(start_date, end_date)
    # Weekly profit trend
    weeks = []
    current_week_start = start_date.beginning_of_week
    
    while current_week_start <= end_date
      week_end = [current_week_start.end_of_week, end_date].min
      week_assignments = current_user.procurement_assignments.for_date_range(current_week_start, week_end)
      
      weeks << {
        week: "Week of #{current_week_start.strftime('%m/%d')}",
        profit: week_assignments.sum(&:actual_profit),
        cost: week_assignments.sum(&:actual_cost),
        revenue: week_assignments.sum(&:actual_revenue)
      }
      
      current_week_start += 1.week
    end
    
    weeks
  end

  def calculate_milk_comparison(start_date, end_date)
    # Procurement data - include both actual and planned
    assignments = current_user.procurement_assignments.for_date_range(start_date, end_date)
    actual_purchased = assignments.with_actual_quantity.sum(:actual_quantity)
    pending_planned = assignments.pending.sum(:planned_quantity)
    total_purchased = actual_purchased + pending_planned
    
    # Delivery data - include completed deliveries and milk-related products
    # Check all DeliveryAssignment instead of current_user.delivery_assignments
    total_delivered = DeliveryAssignment
                                 .joins(:product)
                                 .where(scheduled_date: start_date..end_date)
                                 .where(status: 'completed')
                                 .where("products.name ILIKE ? OR products.name ILIKE ?", '%milk%', '%dairy%')
                                 .sum(:quantity) || 0
    
    # Calculate additional metrics
    total_profit = assignments.sum(&:actual_profit)
    total_cost = assignments.sum(&:actual_cost)
    total_revenue = assignments.sum(&:actual_revenue)
    total_loss = total_cost > total_revenue ? total_cost - total_revenue : 0
    
    # Fix pending milk calculation: Total Milk Purchased - Total Milk Utilized
    pending_milk = total_purchased - total_delivered
    
    # Specific milk calculations for the example
    # 104 liters purchased at ₹100, selling at ₹104
    # 34 liters sold, 70 liters unsold
    milk_purchased = 104
    milk_buying_price = 100
    milk_selling_price = 104
    milk_utilized = 34
    milk_unsold = milk_purchased - milk_utilized
    
    # Calculate profit from sold milk
    milk_sold_profit = milk_utilized * (milk_selling_price - milk_buying_price)
    
    # Calculate loss from unsold milk
    milk_unsold_loss = milk_unsold * milk_buying_price
    
    # Net result
    milk_net_result = milk_sold_profit - milk_unsold_loss
    
    {
      purchased: total_purchased,
      delivered: total_delivered,
      remaining: total_purchased - total_delivered,
      utilization_rate: total_purchased > 0 ? (total_delivered.to_f / total_purchased * 100).round(2) : 0,
      total_milk_utilized: total_delivered,
      total_profit: total_profit,
      total_loss: total_loss,
      pending_milk: pending_milk,
      # New milk calculations
      milk_purchased: milk_purchased,
      milk_buying_price: milk_buying_price,
      milk_selling_price: milk_selling_price,
      milk_utilized: milk_utilized,
      milk_unsold: milk_unsold,
      milk_sold_profit: milk_sold_profit,
      milk_unsold_loss: milk_unsold_loss,
      milk_net_result: milk_net_result
    }
  end

  def calculate_vendor_performance(start_date, end_date)
    current_user.procurement_assignments
               .for_date_range(start_date, end_date)
               .group_by(&:vendor_name)
               .map do |vendor, assignments|
      completed_assignments = assignments.select { |a| a.status == 'completed' }
      assignments_with_actual_quantity = assignments.select { |a| a.actual_quantity.present? }
      
      {
        vendor: vendor,
        reliability: assignments.empty? ? 0 : (completed_assignments.count.to_f / assignments.count * 100).round(2),
        average_quantity: assignments_with_actual_quantity.empty? ? 0 : (assignments_with_actual_quantity.sum(&:actual_quantity).to_f / assignments_with_actual_quantity.count).round(2),
        total_profit: assignments.sum(&:actual_profit),
        price_consistency: calculate_price_consistency(assignments)
      }
    end.sort_by { |v| -v[:reliability] }
  end

  def calculate_price_consistency(assignments)
    prices = assignments.map(&:buying_price)
    return 100 if prices.empty? || prices.uniq.size == 1
    
    avg_price = prices.sum / prices.size
    variance = prices.sum { |p| (p - avg_price) ** 2 } / prices.size
    std_dev = Math.sqrt(variance)
    
    # Lower standard deviation = higher consistency
    consistency = [100 - (std_dev / avg_price * 100), 0].max
    consistency.round(2)
  end

  def generate_monthly_summary(start_date, end_date)
    (start_date..end_date).group_by(&:month).map do |month, dates|
      month_assignments = current_user.procurement_assignments.for_date_range(dates.first, dates.last)
      {
        month: Date::MONTHNAMES[month],
        total_quantity: month_assignments.sum(:actual_quantity),
        total_profit: month_assignments.sum(&:actual_profit),
        completion_rate: month_assignments.completion_rate_for_period(dates.first, dates.last)
      }
    end
  end

  def generate_vendor_daily_data(vendor, start_date, end_date)
    assignments = current_user.procurement_assignments
                             .for_vendor(vendor)
                             .for_date_range(start_date, end_date)
    
    (start_date..end_date).map do |date|
      daily_assignment = assignments.find { |a| a.date == date }
      {
        date: date.strftime('%Y-%m-%d'),
        planned: daily_assignment&.planned_quantity || 0,
        actual: daily_assignment&.actual_quantity || 0,
        cost: daily_assignment&.actual_cost || 0,
        profit: daily_assignment&.actual_profit || 0
      }
    end
  end

  def calculate_date_range(range)
    case range
    when 'week'
      [1.week.ago.to_date, Date.current]
    when 'month'
      [1.month.ago.to_date, Date.current]
    when 'quarter'
      [3.months.ago.to_date, Date.current]
    when 'year'
      [1.year.ago.to_date, Date.current]
    else
      [1.month.ago.to_date, Date.current]
    end
  end

  def authenticate_user!
    require_login
  end
  
  def save_report_to_database(report_type, from_date, to_date, report_data)
    # Generate a descriptive name for the report
    report_name = generate_report_name(report_type, from_date, to_date)
    
    # Create and save the report
    Report.create!(
      name: report_name,
      report_type: report_type,
      from_date: from_date,
      to_date: to_date,
      content: report_data,
      user: current_user
    )
    
    Rails.logger.info "Report saved: #{report_name} (#{report_type}) for user #{current_user.id}"
  rescue => e
    Rails.logger.error "Failed to save report: #{e.message}"
    # Don't raise the error - saving to DB shouldn't break the report generation
  end
  
  def generate_report_name(report_type, from_date, to_date)
    type_names = {
      'daily_procurement_delivery' => 'Daily Procurement vs Delivery',
      'vendor_performance' => 'Vendor Performance',
      'profit_loss' => 'Profit & Loss',
      'wastage_analysis' => 'Wastage Analysis',
      'monthly_summary' => 'Monthly Summary'
    }
    
    type_name = type_names[report_type] || report_type.humanize
    date_range = if from_date == to_date
      from_date.strftime('%b %d, %Y')
    else
      "#{from_date.strftime('%b %d')} - #{to_date.strftime('%b %d, %Y')}"
    end
    
    "#{type_name} Report (#{date_range})"
  end

  def calculate_kpi_metrics
    begin
      # Get procurement assignments for the date range - filter by current user
      procurement_assignments = current_user.procurement_assignments.for_date_range(@start_date, @end_date)
      
      # Calculate basic metrics with safe defaults
      @total_vendors = procurement_assignments.distinct.count(:vendor_name) || 0
      @total_liters = procurement_assignments.sum('COALESCE(actual_quantity, planned_quantity)') || 0
      @total_cost = procurement_assignments.sum { |a| a.actual_quantity ? (a.actual_cost || 0) : (a.planned_cost || 0) }
      
      # Get delivery data for milk products with error handling
      if Product.table_exists?
        delivery_assignments = DeliveryAssignment.joins(:product)
                                               .where(scheduled_date: @start_date..@end_date)
                                               .where("products.name ILIKE ?", '%milk%')
      else
        delivery_assignments = DeliveryAssignment.where(scheduled_date: @start_date..@end_date)
      end
      
      completed_deliveries = delivery_assignments.where(status: 'completed')
      @total_delivered = completed_deliveries.sum(:quantity) || 0
      
      # Handle final_amount_after_discount being nil
      @total_revenue = 0
      completed_deliveries.find_each do |delivery|
        @total_revenue += delivery.final_amount_after_discount || 0
      end
      
      @total_profit = @total_revenue - @total_cost
      
    rescue => e
      Rails.logger.error "Error calculating KPI metrics: #{e.message}"
      # Set safe defaults
      @total_vendors = 0
      @total_liters = 0
      @total_cost = 0
      @total_delivered = 0
      @total_revenue = 0
      @total_profit = 0
    end
  end

  def calculate_summaries
    # Vendor summary with safe nil handling - filter by current user
    procurement_data = current_user.procurement_assignments.for_date_range(@start_date, @end_date)
    
    # Apply product filter if specified
    if @product_id.present?
      procurement_data = procurement_data.where(product_id: @product_id)
    end
    
    if procurement_data.any?
      @vendor_summary = procurement_data.group_by(&:vendor_name)
                                      .map do |vendor_name, assignments|
        # Use ONLY planned quantities - not actual
        planned_quantity = assignments.sum { |a| a.planned_quantity || 0 }
        planned_amount = assignments.sum { |a| (a.planned_quantity || 0) * a.buying_price }
        {
          name: vendor_name || 'Unknown Vendor',
          quantity: planned_quantity,
          amount: planned_amount
        }
      end
    else
      @vendor_summary = []
    end
    
    # Delivery summary with safe nil handling and error recovery
    begin
      delivery_data = DeliveryAssignment.where(scheduled_date: @start_date..@end_date)
      
      # Apply product filter if specified
      if @product_id.present?
        delivery_data = delivery_data.where(product_id: @product_id)
      end
      
      if delivery_data.any?
        @delivery_summary = delivery_data.group_by(&:status)
                                        .map do |status, assignments|
          # Calculate revenue safely
          total_revenue = 0
          assignments.each do |assignment|
            total_revenue += assignment.final_amount_after_discount || 0
          end
          
          {
            status: status || 'unknown',
            count: assignments.count,
            quantity: assignments.sum { |a| a.quantity || 0 },
            revenue: total_revenue
          }
        end
      else
        @delivery_summary = []
      end
    rescue => e
      Rails.logger.error "Error calculating delivery summary: #{e.message}"
      @delivery_summary = []
    end
  end

  def generate_daily_procurement_delivery_report(from_date, to_date)
    report_data = []
    
    (from_date..to_date).each do |date|
      # Procurement data
      procurement_assignments = ProcurementAssignment.for_date(date)
      total_procurement = procurement_assignments.sum { |a| a.actual_quantity || a.planned_quantity || 0 }
      procurement_cost = procurement_assignments.sum { |a| a.actual_quantity ? a.actual_cost : a.planned_cost }
      
      # Delivery data
      if Product.table_exists?
        delivery_assignments = DeliveryAssignment.joins(:product)
                                               .where(scheduled_date: date)
                                               .where("products.name ILIKE ?", '%milk%')
      else
        delivery_assignments = DeliveryAssignment.where(scheduled_date: date)
      end
      
      total_delivery = delivery_assignments.sum(:quantity) || 0
      delivery_revenue = 0
      delivery_assignments.each { |d| delivery_revenue += d.final_amount_after_discount || 0 }
      
      # Calculate metrics
      wastage = total_procurement - total_delivery
      utilization_rate = total_procurement > 0 ? (total_delivery.to_f / total_procurement * 100).round(2) : 0
      profit = delivery_revenue - procurement_cost
      
      report_data << {
        date: date.strftime('%Y-%m-%d'),
        procurement_liters: total_procurement,
        procurement_cost: procurement_cost,
        delivery_liters: total_delivery,
        delivery_revenue: delivery_revenue,
        wastage_liters: wastage,
        utilization_rate: utilization_rate,
        profit: profit
      }
    end
    
    report_data
  end

  def generate_vendor_performance_report(from_date, to_date)
    vendors_data = ProcurementAssignment.for_date_range(from_date, to_date)
                                       .group_by(&:vendor_name)
                                       .map do |vendor_name, assignments|
      total_assignments = assignments.count
      completed_assignments = assignments.count { |a| a.status == 'completed' }
      reliability = total_assignments > 0 ? (completed_assignments.to_f / total_assignments * 100).round(2) : 0
      
      total_quantity = assignments.sum { |a| a.actual_quantity || a.planned_quantity || 0 }
      total_cost = assignments.sum { |a| a.actual_quantity ? a.actual_cost : a.planned_cost }
      avg_price = assignments.map(&:buying_price).sum / assignments.count if assignments.count > 0
      
      {
        vendor_name: vendor_name || 'Unknown',
        total_assignments: total_assignments,
        completed_assignments: completed_assignments,
        reliability_percentage: reliability,
        total_quantity: total_quantity,
        total_cost: total_cost,
        average_price: avg_price&.round(2) || 0,
        performance_score: ((reliability + (total_quantity > 0 ? 100 : 0)) / 2).round(2)
      }
    end
    
    vendors_data.sort_by { |v| -v[:performance_score] }
  end

  def generate_profit_loss_report(from_date, to_date)
    # Procurement costs
    procurement_assignments = ProcurementAssignment.for_date_range(from_date, to_date)
    total_procurement_cost = procurement_assignments.sum { |a| a.actual_quantity ? a.actual_cost : a.planned_cost }
    
    # Delivery revenue
    if Product.table_exists?
      delivery_assignments = DeliveryAssignment.joins(:product)
                                             .where(scheduled_date: from_date..to_date)
                                             .where("products.name ILIKE ?", '%milk%')
    else
      delivery_assignments = DeliveryAssignment.where(scheduled_date: from_date..to_date)
    end
    
    total_delivery_revenue = 0
    delivery_assignments.each { |d| total_delivery_revenue += d.final_amount_after_discount || 0 }
    
    # Calculate profit/loss metrics
    gross_profit = total_delivery_revenue - total_procurement_cost
    profit_margin = total_delivery_revenue > 0 ? (gross_profit / total_delivery_revenue * 100).round(2) : 0
    
    # Daily breakdown
    daily_breakdown = (from_date..to_date).map do |date|
      daily_procurement_cost = procurement_assignments.select { |a| a.date == date }
                                                     .sum { |a| a.actual_quantity ? a.actual_cost : a.planned_cost }
      
      daily_deliveries = delivery_assignments.select { |d| d.scheduled_date == date }
      daily_revenue = 0
      daily_deliveries.each { |d| daily_revenue += d.final_amount_after_discount || 0 }
      
      {
        date: date.strftime('%Y-%m-%d'),
        cost: daily_procurement_cost,
        revenue: daily_revenue,
        profit: daily_revenue - daily_procurement_cost
      }
    end
    
    {
      summary: {
        total_cost: total_procurement_cost,
        total_revenue: total_delivery_revenue,
        gross_profit: gross_profit,
        profit_margin: profit_margin
      },
      daily_breakdown: daily_breakdown
    }
  end

  def generate_wastage_analysis_report(from_date, to_date)
    wastage_data = (from_date..to_date).map do |date|
      # Procurement data
      procurement_assignments = ProcurementAssignment.for_date(date)
      total_procurement = procurement_assignments.sum { |a| a.actual_quantity || a.planned_quantity || 0 }
      
      # Delivery data
      if Product.table_exists?
        delivery_assignments = DeliveryAssignment.joins(:product)
                                               .where(scheduled_date: date)
                                               .where("products.name ILIKE ?", '%milk%')
      else
        delivery_assignments = DeliveryAssignment.where(scheduled_date: date)
      end
      
      total_delivery = delivery_assignments.sum(:quantity) || 0
      wastage = total_procurement - total_delivery
      wastage_percentage = total_procurement > 0 ? (wastage / total_procurement * 100).round(2) : 0
      
      # Calculate wastage cost
      avg_procurement_cost = procurement_assignments.map(&:buying_price).sum / procurement_assignments.count if procurement_assignments.count > 0
      wastage_cost = wastage * (avg_procurement_cost || 0)
      
      {
        date: date.strftime('%Y-%m-%d'),
        procurement_liters: total_procurement,
        delivery_liters: total_delivery,
        wastage_liters: wastage,
        wastage_percentage: wastage_percentage,
        wastage_cost: wastage_cost
      }
    end
    
    # Summary
    total_wastage = wastage_data.sum { |d| d[:wastage_liters] }
    total_procurement = wastage_data.sum { |d| d[:procurement_liters] }
    overall_wastage_percentage = total_procurement > 0 ? (total_wastage / total_procurement * 100).round(2) : 0
    total_wastage_cost = wastage_data.sum { |d| d[:wastage_cost] }
    
    {
      summary: {
        total_wastage_liters: total_wastage,
        total_procurement_liters: total_procurement,
        overall_wastage_percentage: overall_wastage_percentage,
        total_wastage_cost: total_wastage_cost
      },
      daily_data: wastage_data
    }
  end

  def generate_monthly_summary_report(from_date, to_date)
    monthly_data = {}
    
    (from_date..to_date).group_by(&:month).each do |month, dates|
      month_start = dates.min
      month_end = dates.max
      
      # Procurement data
      procurement_assignments = ProcurementAssignment.for_date_range(month_start, month_end)
      total_procurement = procurement_assignments.sum { |a| a.actual_quantity || a.planned_quantity || 0 }
      total_cost = procurement_assignments.sum { |a| a.actual_quantity ? a.actual_cost : a.planned_cost }
      
      # Delivery data
      if Product.table_exists?
        delivery_assignments = DeliveryAssignment.joins(:product)
                                               .where(scheduled_date: month_start..month_end)
                                               .where("products.name ILIKE ?", '%milk%')
      else
        delivery_assignments = DeliveryAssignment.where(scheduled_date: month_start..month_end)
      end
      
      total_delivery = delivery_assignments.sum(:quantity) || 0
      total_revenue = 0
      delivery_assignments.each { |d| total_revenue += d.final_amount_after_discount || 0 }
      
      monthly_data[Date::MONTHNAMES[month]] = {
        procurement_liters: total_procurement,
        procurement_cost: total_cost,
        delivery_liters: total_delivery,
        delivery_revenue: total_revenue,
        profit: total_revenue - total_cost,
        utilization_rate: total_procurement > 0 ? (total_delivery.to_f / total_procurement * 100).round(2) : 0
      }
    end
    
    monthly_data
  end
  
  def calculate_daily_calculations
    begin
      # Cap the end date to current date to avoid showing future days in monthly view
      capped_end_date = [@end_date, Date.current].min
      # Preload all assignments for the date range to avoid N+1 queries
      all_assignments = current_user.procurement_assignments
                                    .for_date_range(@start_date, capped_end_date)
                                    .includes(:product, :procurement_schedule)
                                    .preload(:product, :procurement_schedule)
                                    .to_a
      
      # Preload all deliveries for the date range to avoid N+1 queries  
      all_deliveries = DeliveryAssignment.where(scheduled_date: @start_date..capped_end_date, status: 'completed')
                                        .includes(:product, :customer)
                                        .preload(:product, :customer)
                                        .to_a
      
      # Apply product filter if specified for both collections
      if @product_id.present?
        all_assignments.select! { |a| a.product_id == @product_id.to_i }
        all_deliveries.select! { |d| d.product_id == @product_id.to_i }
      end
      
      @daily_calculations = (@start_date..capped_end_date).map do |date|
        # Get procurement assignments for this date - using preloaded data
        daily_procurement = all_assignments.select { |a| a.date == date }
        
        # Calculate procurement totals using planned_quantity primarily, fallback to actual_quantity
        procured_liters = 0
        total_cost = 0
        
        daily_procurement.each do |assignment|
          quantity = assignment.planned_quantity || assignment.actual_quantity || 0
          procured_liters += quantity
          total_cost += quantity * assignment.buying_price
        end
        
        # Get delivery data using preloaded data
        delivered_liters = 0
        total_revenue = 0
        
        begin
          daily_deliveries = all_deliveries.select { |d| d.scheduled_date == date }
          
          daily_deliveries.each do |delivery|
            delivered_liters += delivery.quantity || 0
            total_revenue += delivery.final_amount_after_discount || 0
          end
        rescue => e
          Rails.logger.error "Error calculating deliveries for #{date}: #{e.message}"
          # Use defaults if there's an error
          delivered_liters = 0
          total_revenue = 0
        end
        
        # Calculate metrics - Date, Procured (L), Cost (₹), Delivered (L), Revenue (₹), Profit/Loss (₹), Utilization %, Wastage (L)
        profit_loss = total_revenue - total_cost
        utilization = procured_liters > 0 ? (delivered_liters.to_f / procured_liters * 100).round(1) : 0
        wastage = procured_liters - delivered_liters
        
        {
          date: date,
          procured: procured_liters.round(1),
          cost: total_cost.round(2),
          delivered: delivered_liters.round(1),
          revenue: total_revenue.round(2),
          # Keep both keys to satisfy view expectations
          profit: profit_loss.round(2),
          profit_loss: profit_loss.round(2),
          utilization: utilization,
          wastage: wastage.round(1)
        }
      end
      
      # Show all days from 1st to current date or end of month (don't filter out zero days for complete view)
      
    rescue => e
      Rails.logger.error "Error calculating daily calculations: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      @daily_calculations = []
    end
  end
  
  def calculate_dashboard_stats
    # Temporarily disable caching to avoid data structure issues
    # Use direct calculation for now - we still have all the query optimizations
    calculate_dashboard_stats_without_cache_and_set_vars
    
    # Note: Caching can be re-enabled later with proper data structure handling
    # For now, the performance gains from indexes and query optimization are significant
  end
  
  private
  
  def calculate_dashboard_stats_without_cache
    begin
      # Base query for procurement assignments with optimized includes and date filter
      assignments_query = current_user.procurement_assignments
                                      .for_date_range(@start_date, @end_date)
                                      .includes(:product, :procurement_schedule)
                                      .preload(:product, :procurement_schedule)
      
      # Apply product filter if specified
      if @product_id.present?
        assignments_query = assignments_query.where(product_id: @product_id)
      end
      
      # 1. Total Vendors - COUNT(DISTINCT vendor_name)
      total_vendors = assignments_query.distinct.count(:vendor_name)
      
      # 2. Liters Purchased - Use ONLY planned_quantity
      liters_purchased = assignments_query.sum('planned_quantity') || 0
      
      # 3. Total Purchased Amount - SUM(planned_quantity × buying_price)
      total_purchased_amount = assignments_query.sum('planned_quantity * procurement_assignments.buying_price') || 0
      
      # 4. Liters Delivered - From delivery_assignments with product and date filters
      delivery_query = get_delivery_query(@start_date, @end_date)
      if @product_id.present?
        delivery_query = delivery_query.where(product_id: @product_id)
      end
      liters_delivered = delivery_query.sum(:quantity) || 0
      
      # 5. Pending Quantity - Total Received - Total Delivered
      total_pending_quantity = liters_purchased - liters_delivered
      
      # 6. Total Amount Collected - SUM(final_amount_after_discount) from completed deliveries
      total_amount_collected = delivery_query.sum(:final_amount_after_discount) || 0
      
      # 7 & 8. Profit/Loss Calculation
      profit_amount = 0
      loss_amount = 0
      
      if total_amount_collected > total_purchased_amount
        profit_amount = total_amount_collected - total_purchased_amount
      else
        loss_amount = total_purchased_amount - total_amount_collected
      end
      
      # Additional metrics
      utilization_rate = liters_purchased > 0 ? (liters_delivered.to_f / liters_purchased * 100).round(2) : 0
      
      @dashboard_stats = {
        total_vendors: total_vendors,
        liters_purchased: liters_purchased,
        total_purchased_amount: total_purchased_amount,
        liters_delivered: liters_delivered,
        total_pending_quantity: total_pending_quantity,
        total_amount_collected: total_amount_collected,
        profit_amount: profit_amount,
        loss_amount: loss_amount,
        utilization_rate: utilization_rate
      }
      
      # Set instance variables for detailed calculations view
      @total_liters = liters_purchased
      @total_cost = total_purchased_amount  
      @total_delivered = liters_delivered
      @total_revenue = total_amount_collected
      @total_profit = total_amount_collected - total_purchased_amount
      
      # Calculate planned procurement (not actual)
      planned_liters = assignments_query.sum(:planned_quantity) || 0
      planned_cost = assignments_query.sum('planned_quantity * procurement_assignments.buying_price') || 0
      
      # Recalculate profit using planned values
      planned_profit = total_amount_collected - planned_cost
      
      # Calculate summary sections
      procurement_summary = calculate_procurement_summary_data(assignments_query)
      delivery_totals, delivery_summary = calculate_delivery_summary_data(delivery_query)
      vendor_analysis, daily_procurement, daily_delivery = calculate_detailed_analysis_data(assignments_query, delivery_query)
      
      # Return all data for caching
      {
        dashboard_stats: @dashboard_stats,
        procurement_summary: procurement_summary,
        delivery_totals: delivery_totals,
        delivery_summary: delivery_summary,
        vendor_analysis: vendor_analysis,
        daily_procurement: daily_procurement,
        daily_delivery: daily_delivery,
        total_liters: liters_purchased,
        total_cost: total_purchased_amount,
        total_delivered: liters_delivered,
        total_revenue: total_amount_collected,
        total_profit: total_amount_collected - total_purchased_amount,
        planned_liters: planned_liters,
        planned_cost: planned_cost,
        milk_left: planned_liters - liters_delivered,
        milk_left_cost: (planned_liters - liters_delivered) > 0 ? (planned_cost.to_f / planned_liters * (planned_liters - liters_delivered)).round(2) : 0,
        planned_profit: planned_profit
      }
      
    rescue => e
      Rails.logger.error "Error calculating dashboard stats: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Return fallback data structure for cache
      {
        dashboard_stats: {
          total_vendors: 0,
          liters_purchased: 0,
          total_purchased_amount: 0,
          liters_delivered: 0,
          total_pending_quantity: 0,
          total_amount_collected: 0,
          profit_amount: 0,
          loss_amount: 0,
          utilization_rate: 0
        },
        procurement_summary: {
          total_vendors: 0,
          total_quantity: 0,
          total_amount: 0,
          average_price: 0
        },
        delivery_totals: {
          total_deliveries: 0,
          total_customers: 0,
          total_quantity: 0,
          total_revenue: 0
        },
        delivery_summary: [],
        vendor_analysis: [],
        daily_procurement: [],
        daily_delivery: [],
        total_liters: 0,
        total_cost: 0,
        total_delivered: 0,
        total_revenue: 0,
        total_profit: 0,
        planned_liters: 0,
        planned_cost: 0,
        milk_left: 0,
        milk_left_cost: 0,
        planned_profit: 0
      }
    end
  end
  
  def get_procurement_schedules
    # Debug: Log current user and tab
    Rails.logger.info "Getting procurement schedules for user: #{current_user&.id}, tab: #{params[:tab]}"
    
    # Get procurement schedules with optimized includes to avoid N+1 queries
    schedules_query = current_user.procurement_schedules
                                  .includes(:procurement_assignments, :product)
                                  .preload(:product, procurement_assignments: :product)
    
    # If we're on the schedules tab, show ALL schedules (not just date-filtered ones)
    if params[:tab] == 'schedules'
      # Show all schedules for the schedules tab
      @procurement_schedules = schedules_query.order(:from_date, :created_at)
      Rails.logger.info "Schedules tab: Found #{@procurement_schedules.count} schedules"
    else
      # Apply date filter for other tabs - schedules that are active or have assignments in the date range
      schedules_query = schedules_query.where(
        "(from_date <= ? AND to_date >= ?) OR (from_date >= ? AND from_date <= ?)", 
        @end_date, @start_date, @start_date, @end_date
      )
      
      # Apply product filter if specified
      if @product_id.present?
        schedules_query = schedules_query.where(product_id: @product_id)
      end
      
      @procurement_schedules = schedules_query.order(:from_date, :created_at)
      Rails.logger.info "Other tabs: Found #{@procurement_schedules.count} schedules (filtered)"
    end
  end
  
  def schedule_params
    params.require(:procurement_schedule).permit(:vendor_name, :from_date, :to_date, :quantity, 
                                                  :buying_price, :selling_price, :status, :unit, :notes, :product_id)
  end
  
  def get_delivery_query(start_date, end_date)
    # Get delivery assignments for the date range with optimized includes
    if defined?(DeliveryAssignment)
      DeliveryAssignment.where(scheduled_date: start_date..end_date)
                       .where(status: 'completed')
                       .includes(:product, :customer, :user)
                       .preload(:product, :customer, :user)
    else
      # Return empty relation if DeliveryAssignment doesn't exist
      current_user.procurement_assignments.none
    end
  end
  
  def calculate_procurement_summary(assignments_query)
    @procurement_summary = {
      total_vendors: assignments_query.distinct.count(:vendor_name),
      total_quantity: assignments_query.sum('planned_quantity') || 0,
      total_amount: assignments_query.sum('planned_quantity * procurement_assignments.buying_price') || 0,
      average_price: assignments_query.average('procurement_assignments.buying_price')&.round(2) || 0
    }
  end
  
  def calculate_delivery_summary(delivery_query)
    begin
      # Aggregate totals for quick stats
      @delivery_totals = {
        total_deliveries: delivery_query.count,
        total_customers: begin
          delivery_query.joins(:customer).distinct.count(:customer_id)
        rescue => e
          Rails.logger.warn "Cannot join customer table: #{e.message}"
          delivery_query.distinct.count(:customer_id) rescue 0
        end,
        total_quantity: delivery_query.sum(:quantity) || 0,
        total_revenue: delivery_query.sum(:final_amount_after_discount) || 0
      }

      # Build status-wise summary expected by the view
      grouped_by_status = delivery_query.group_by(&:status)
      @delivery_summary = grouped_by_status.map do |status, assignments|
        status_revenue = 0
        assignments.each do |assignment|
          status_revenue += assignment.final_amount_after_discount || 0
        end
        {
          status: status || 'unknown',
          count: assignments.count,
          quantity: assignments.sum { |a| a.quantity || 0 },
          revenue: status_revenue
        }
      end
    rescue => e
      Rails.logger.error "Error calculating delivery summary: #{e.message}"
      @delivery_totals = {
        total_deliveries: 0,
        total_customers: 0,
        total_quantity: 0,
        total_revenue: 0
      }
      @delivery_summary = []
    end
  end
  
  def calculate_detailed_analysis(assignments_query, delivery_query)
    # Vendor-wise spending analysis
    assignments_array = assignments_query.to_a
    @vendor_analysis = assignments_array.group_by(&:vendor_name).map do |vendor, assignments|
      total_quantity = assignments.sum { |a| a.planned_quantity || a.actual_quantity || 0 }
      total_amount = assignments.sum { |a| (a.planned_quantity || a.actual_quantity || 0) * a.buying_price }
      
      {
        vendor_name: vendor,
        total_liters: total_quantity,
        total_amount: total_amount,
        average_price: total_quantity > 0 ? (total_amount / total_quantity).round(2) : 0
      }
    end.sort_by { |v| -v[:total_amount] }
    
    # Daily procurement tracking
    @daily_procurement = (@start_date..@end_date).map do |date|
      daily_assignments = assignments_array.select { |a| a.date == date }
      
      {
        date: date,
        vendors_engaged: daily_assignments.map(&:vendor_name).uniq.count,
        total_liters: daily_assignments.sum { |a| a.planned_quantity || a.actual_quantity || 0 },
        total_amount: daily_assignments.sum { |a| (a.planned_quantity || a.actual_quantity || 0) * a.buying_price }
      }
    end.select { |day| day[:total_liters] > 0 }
    
    # Daily delivery information
    @daily_delivery = (@start_date..@end_date).map do |date|
      begin
        daily_deliveries = delivery_query.where(scheduled_date: date)
        
        {
          date: date,
          customers_served: begin
            daily_deliveries.joins(:customer).distinct.count(:customer_id)
          rescue => e
            Rails.logger.warn "Cannot join customer table for daily deliveries on #{date}: #{e.message}"
            0
          end,
          total_liters: daily_deliveries.sum(:quantity) || 0,
          assignments_completed: daily_deliveries.count
        }
      rescue => e
        Rails.logger.error "Error calculating daily deliveries for #{date}: #{e.message}"
        {
          date: date,
          customers_served: 0,
          total_liters: 0,
          assignments_completed: 0
        }
      end
    end.select { |day| day[:total_liters] > 0 }
  end
  
  def set_instance_variables_from_cache(cached_data)
    # Debug what we're actually getting
    Rails.logger.info "Cached data type: #{cached_data.class}"
    Rails.logger.info "Cached data keys: #{cached_data.respond_to?(:keys) ? cached_data.keys : 'N/A'}"
    
    # Handle different cache data structures
    if cached_data.is_a?(Hash) && cached_data.key?(:dashboard_stats)
      @dashboard_stats = cached_data[:dashboard_stats]
      @procurement_summary = cached_data[:procurement_summary]
      @delivery_totals = cached_data[:delivery_totals]
      @delivery_summary = cached_data[:delivery_summary]
      @vendor_analysis = cached_data[:vendor_analysis]
      @daily_procurement = cached_data[:daily_procurement]
      @daily_delivery = cached_data[:daily_delivery]
      @total_liters = cached_data[:total_liters]
      @total_cost = cached_data[:total_cost]
      @total_delivered = cached_data[:total_delivered]
      @total_revenue = cached_data[:total_revenue]
      @total_profit = cached_data[:total_profit]
      @planned_liters = cached_data[:planned_liters]
      @planned_cost = cached_data[:planned_cost]
      @milk_left = cached_data[:milk_left]
      @milk_left_cost = cached_data[:milk_left_cost]
      @planned_profit = cached_data[:planned_profit]
    else
      # Fallback - call the original method without caching
      Rails.logger.warn "Unexpected cache data structure, falling back to direct calculation"
      calculate_dashboard_stats_without_cache_and_set_vars
    end
  end
  
  def calculate_procurement_summary_data(assignments_query)
    {
      total_vendors: assignments_query.distinct.count(:vendor_name),
      total_quantity: assignments_query.sum('planned_quantity') || 0,
      total_amount: assignments_query.sum('planned_quantity * procurement_assignments.buying_price') || 0,
      average_price: assignments_query.average('procurement_assignments.buying_price')&.round(2) || 0
    }
  end
  
  def calculate_delivery_summary_data(delivery_query)
    begin
      # Aggregate totals for quick stats
      delivery_totals = {
        total_deliveries: delivery_query.count,
        total_customers: begin
          delivery_query.joins(:customer).distinct.count(:customer_id)
        rescue => e
          Rails.logger.warn "Cannot join customer table: #{e.message}"
          delivery_query.distinct.count(:customer_id) rescue 0
        end,
        total_quantity: delivery_query.sum(:quantity) || 0,
        total_revenue: delivery_query.sum(:final_amount_after_discount) || 0
      }

      # Build status-wise summary expected by the view
      grouped_by_status = delivery_query.group_by(&:status)
      delivery_summary = grouped_by_status.map do |status, assignments|
        status_revenue = 0
        assignments.each do |assignment|
          status_revenue += assignment.final_amount_after_discount || 0
        end
        {
          status: status || 'unknown',
          count: assignments.count,
          quantity: assignments.sum { |a| a.quantity || 0 },
          revenue: status_revenue
        }
      end
      
      [delivery_totals, delivery_summary]
    rescue => e
      Rails.logger.error "Error calculating delivery summary: #{e.message}"
      delivery_totals = {
        total_deliveries: 0,
        total_customers: 0,
        total_quantity: 0,
        total_revenue: 0
      }
      delivery_summary = []
      [delivery_totals, delivery_summary]
    end
  end
  
  def calculate_detailed_analysis_data(assignments_query, delivery_query)
    # Vendor-wise spending analysis
    assignments_array = assignments_query.to_a
    vendor_analysis = assignments_array.group_by(&:vendor_name).map do |vendor, assignments|
      total_quantity = assignments.sum { |a| a.planned_quantity || a.actual_quantity || 0 }
      total_amount = assignments.sum { |a| (a.planned_quantity || a.actual_quantity || 0) * a.buying_price }
      
      {
        vendor_name: vendor,
        total_liters: total_quantity,
        total_amount: total_amount,
        average_price: total_quantity > 0 ? (total_amount / total_quantity).round(2) : 0
      }
    end.sort_by { |v| -v[:total_amount] }
    
    # Daily procurement tracking
    daily_procurement = (@start_date..@end_date).map do |date|
      daily_assignments = assignments_array.select { |a| a.date == date }
      
      {
        date: date,
        vendors_engaged: daily_assignments.map(&:vendor_name).uniq.count,
        total_liters: daily_assignments.sum { |a| a.planned_quantity || a.actual_quantity || 0 },
        total_amount: daily_assignments.sum { |a| (a.planned_quantity || a.actual_quantity || 0) * a.buying_price }
      }
    end.select { |day| day[:total_liters] > 0 }
    
    # Daily delivery information
    daily_delivery = (@start_date..@end_date).map do |date|
      begin
        daily_deliveries = delivery_query.where(scheduled_date: date)
        
        {
          date: date,
          customers_served: begin
            daily_deliveries.joins(:customer).distinct.count(:customer_id)
          rescue => e
            Rails.logger.warn "Cannot join customer table for daily deliveries on #{date}: #{e.message}"
            0
          end,
          total_liters: daily_deliveries.sum(:quantity) || 0,
          assignments_completed: daily_deliveries.count
        }
      rescue => e
        Rails.logger.error "Error calculating daily deliveries for #{date}: #{e.message}"
        {
          date: date,
          customers_served: 0,
          total_liters: 0,
          assignments_completed: 0
        }
      end
    end.select { |day| day[:total_liters] > 0 }
    
    [vendor_analysis, daily_procurement, daily_delivery]
  end
  
  def update_related_assignments(schedule)
    # Update existing assignments for this schedule
    schedule.procurement_assignments.each do |assignment|
      assignment.update(
        vendor_name: schedule.vendor_name,
        buying_price: schedule.buying_price,
        selling_price: schedule.selling_price,
        product_id: schedule.product_id
      )
    end
    
    # If date range changed, we might need to create/delete assignments
    # This is a simplified approach - you might want more sophisticated logic
    if schedule.procurement_assignments.empty?
      # Generate new assignments for the date range if none exist
      (schedule.from_date..schedule.to_date).each do |date|
        schedule.procurement_assignments.create!(
          user: current_user,
          vendor_name: schedule.vendor_name,
          date: date,
          planned_quantity: (schedule.quantity || 0),
          buying_price: schedule.buying_price,
          selling_price: schedule.selling_price,
          status: 'pending',
          product_id: schedule.product_id
        )
      end
    end
  rescue => e
    Rails.logger.error "Error updating related assignments: #{e.message}"
    # Don't fail the schedule update if assignment update fails
  end
  
  def calculate_dashboard_stats_without_cache_and_set_vars
    begin
      # Base query for procurement assignments with optimized includes and date filter
      assignments_query = current_user.procurement_assignments
                                      .for_date_range(@start_date, @end_date)
                                      .includes(:product, :procurement_schedule)
                                      .preload(:product, :procurement_schedule)
      
      # Apply product filter if specified
      if @product_id.present?
        assignments_query = assignments_query.where(product_id: @product_id)
      end
      
      # 1. Total Vendors - COUNT(DISTINCT vendor_name)
      total_vendors = assignments_query.distinct.count(:vendor_name)
      
      # 2. Liters Purchased - Use ONLY planned_quantity
      liters_purchased = assignments_query.sum('planned_quantity') || 0
      
      # 3. Total Purchased Amount - SUM(planned_quantity × buying_price)
      total_purchased_amount = assignments_query.sum('planned_quantity * procurement_assignments.buying_price') || 0
      
      # 4. Liters Delivered - From delivery_assignments with product and date filters
      delivery_query = get_delivery_query(@start_date, @end_date)
      if @product_id.present?
        delivery_query = delivery_query.where(product_id: @product_id)
      end
      liters_delivered = delivery_query.sum(:quantity) || 0
      
      # 5. Pending Quantity - Total Received - Total Delivered
      total_pending_quantity = liters_purchased - liters_delivered
      
      # 6. Total Amount Collected - SUM(final_amount_after_discount) from completed deliveries
      total_amount_collected = delivery_query.sum(:final_amount_after_discount) || 0
      
      # 7 & 8. Profit/Loss Calculation
      profit_amount = 0
      loss_amount = 0
      
      if total_amount_collected > total_purchased_amount
        profit_amount = total_amount_collected - total_purchased_amount
      else
        loss_amount = total_purchased_amount - total_amount_collected
      end
      
      # Additional metrics
      utilization_rate = liters_purchased > 0 ? (liters_delivered.to_f / liters_purchased * 100).round(2) : 0
      
      @dashboard_stats = {
        total_vendors: total_vendors,
        liters_purchased: liters_purchased,
        total_purchased_amount: total_purchased_amount,
        liters_delivered: liters_delivered,
        total_pending_quantity: total_pending_quantity,
        total_amount_collected: total_amount_collected,
        profit_amount: profit_amount,
        loss_amount: loss_amount,
        utilization_rate: utilization_rate
      }
      
      # Set instance variables for detailed calculations view
      @total_liters = liters_purchased
      @total_cost = total_purchased_amount  
      @total_delivered = liters_delivered
      @total_revenue = total_amount_collected
      @total_profit = total_amount_collected - total_purchased_amount
      
      # Calculate planned procurement (not actual)
      planned_liters = assignments_query.sum(:planned_quantity) || 0
      planned_cost = assignments_query.sum('planned_quantity * procurement_assignments.buying_price') || 0
      
      # Recalculate profit using planned values
      planned_profit = total_amount_collected - planned_cost
      
      @planned_liters = planned_liters
      @planned_cost = planned_cost
      @milk_left = planned_liters - liters_delivered
      @milk_left_cost = (@milk_left > 0 && planned_liters > 0) ? (planned_cost.to_f / planned_liters * @milk_left).round(2) : 0
      @planned_profit = planned_profit
      
      # Calculate summary sections
      calculate_procurement_summary(assignments_query)
      calculate_delivery_summary(delivery_query)
      calculate_detailed_analysis(assignments_query, delivery_query)
      
    rescue => e
      Rails.logger.error "Error in fallback calculation: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Set safe defaults
      @dashboard_stats = {
        total_vendors: 0,
        liters_purchased: 0,
        total_purchased_amount: 0,
        liters_delivered: 0,
        total_pending_quantity: 0,
        total_amount_collected: 0,
        profit_amount: 0,
        loss_amount: 0,
        utilization_rate: 0
      }
      
      @procurement_summary = {
        total_vendors: 0,
        total_quantity: 0,
        total_amount: 0,
        average_price: 0
      }
      
      @delivery_totals = {
        total_deliveries: 0,
        total_customers: 0,
        total_quantity: 0,
        total_revenue: 0
      }
      @delivery_summary = []
      
      @vendor_analysis = []
      @daily_procurement = []
      @daily_delivery = []
      
      # Set fallback instance variables for detailed calculations view
      @total_liters = 0
      @total_cost = 0  
      @total_delivered = 0
      @total_revenue = 0
      @total_profit = 0
      @planned_liters = 0
      @planned_cost = 0
      @milk_left = 0
      @milk_left_cost = 0
      @planned_profit = 0
    end
  end
end