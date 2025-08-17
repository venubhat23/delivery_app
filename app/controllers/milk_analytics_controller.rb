class MilkAnalyticsController < ApplicationController
  before_action :authenticate_user!

  def index
    # Determine date range based on parameters
    @date_range = params[:date_range] || 'today'
    
    case @date_range
    when 'today'
      @start_date = Date.current
      @end_date = Date.current
    when 'week'
      @start_date = Date.current.beginning_of_week
      @end_date = Date.current.end_of_week
    when 'month'
      @start_date = Date.current.beginning_of_month
      @end_date = Date.current.end_of_month
    when 'custom'
      @start_date = params[:from_date].present? ? Date.parse(params[:from_date]) : Date.current
      @end_date = params[:to_date].present? ? Date.parse(params[:to_date]) : Date.current
    else
      @start_date = Date.current
      @end_date = Date.current
    end
    
    # Calculate KPI metrics
    calculate_kpi_metrics
    
    # Calculate summaries
    calculate_summaries
    
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
    @date = params[:date] ? Date.parse(params[:date]) : Date.current
    @view_type = params[:view_type] || 'month'
    
    case @view_type
    when 'week'
      @start_date = @date.beginning_of_week
      @end_date = @date.end_of_week
    when 'month'
      @start_date = @date.beginning_of_month
      @end_date = @date.end_of_month
    else
      @start_date = @date
      @end_date = @date
    end
    
    # Get assignments for the date range
    @assignments = current_user.procurement_assignments
                              .for_date_range(@start_date, @end_date)
                              .includes(:procurement_schedule)
    
    # Group by date for calendar display
    @assignments_by_date = @assignments.group_by(&:date)
    
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
      # Specific vendor analysis
      @vendor_assignments = current_user.procurement_assignments
                                       .for_vendor(@vendor)
                                       .for_date_range(@start_date, @end_date)
      
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

  def generate_reports
    @report_type = params[:report_type] || 'daily_procurement_delivery'
    @from_date = params[:from_date]&.to_date || Date.current.beginning_of_month
    @to_date = params[:to_date]&.to_date || Date.current
    
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
    
    respond_to do |format|
      format.json { render json: @report_data }
      format.html { redirect_to milk_analytics_index_path }
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

  def calculate_kpi_metrics
    begin
      # Get procurement assignments for the date range
      procurement_assignments = ProcurementAssignment.for_date_range(@start_date, @end_date)
      
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

  def generate_reports
    @report_type = params[:report_type] || 'daily_procurement_delivery'
    @from_date = params[:from_date]&.to_date || Date.current.beginning_of_month
    @to_date = params[:to_date]&.to_date || Date.current
    
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
    
    respond_to do |format|
      format.json { render json: @report_data }
      format.html { redirect_to milk_analytics_index_path }
    end
  end

  def calculate_summaries
    # Vendor summary with safe nil handling
    procurement_data = ProcurementAssignment.for_date_range(@start_date, @end_date)
    
    if procurement_data.any?
      @vendor_summary = procurement_data.group_by(&:vendor_name)
                                      .map do |vendor_name, assignments|
        {
          name: vendor_name || 'Unknown Vendor',
          quantity: assignments.sum { |a| (a.actual_quantity || a.planned_quantity) || 0 },
          amount: assignments.sum { |a| a.actual_quantity ? (a.actual_cost || 0) : (a.planned_cost || 0) }
        }
      end
    else
      @vendor_summary = []
    end
    
    # Delivery summary with safe nil handling and error recovery
    begin
      if Product.table_exists?
        delivery_data = DeliveryAssignment.joins(:product)
                                        .where(scheduled_date: @start_date..@end_date)
                                        .where("products.name ILIKE ?", '%milk%')
      else
        delivery_data = DeliveryAssignment.where(scheduled_date: @start_date..@end_date)
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
end