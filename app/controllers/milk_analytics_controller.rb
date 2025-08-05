class MilkAnalyticsController < ApplicationController
  before_action :authenticate_user!

  def index
    @date_range = params[:date_range] || 'month'
    @start_date, @end_date = calculate_date_range(@date_range)
    
    # Main KPIs
    @kpis = calculate_main_kpis(@start_date, @end_date)
    
    # Chart data
    @daily_chart_data = generate_daily_chart_data(@start_date, @end_date)
    @vendor_chart_data = generate_vendor_chart_data(@start_date, @end_date)
    @profit_trend_data = generate_profit_trend_data(@start_date, @end_date)
    
    # Comparison with delivery data
    @milk_comparison = calculate_milk_comparison(@start_date, @end_date)
    
    # Recent activities
    @recent_schedules = current_user.procurement_schedules.recent.limit(5)
    @pending_assignments = current_user.procurement_assignments.pending.limit(10)
    @overdue_assignments = current_user.procurement_assignments.select(&:is_overdue?).first(5)
    
    # Vendor performance
    @vendor_performance = calculate_vendor_performance(@start_date, @end_date)
    
    # Monthly summary for calendar
    @monthly_summary = generate_monthly_summary(@start_date, @end_date)
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
    
    # Daily summaries
    @daily_summaries = (@start_date..@end_date).map do |date|
      daily_assignments = @assignments.select { |a| a.date == date }
      {
        date: date,
        total_planned: daily_assignments.sum(&:planned_quantity),
        total_actual: daily_assignments.sum { |a| a.actual_quantity || 0 },
        total_cost: daily_assignments.sum(&:actual_cost),
        total_revenue: daily_assignments.sum(&:actual_revenue),
        profit: daily_assignments.sum(&:actual_profit),
        assignments_count: daily_assignments.count,
        completed_count: daily_assignments.count { |a| a.is_completed? }
      }
    end
  end

  def vendor_analysis
    @vendor = params[:vendor]
    @date_range = params[:date_range] || 'month'
    @start_date, @end_date = calculate_date_range(@date_range)
    
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
    @start_date, @end_date = calculate_date_range(@date_range)
    
    # Profit breakdown
    @profit_analysis = {
      total_cost: 0,
      total_revenue: 0,
      gross_profit: 0,
      profit_margin: 0,
      daily_profits: [],
      vendor_profits: []
    }
    
    assignments = current_user.procurement_assignments.for_date_range(@start_date, @end_date)
    
    @profit_analysis[:total_cost] = assignments.sum(&:actual_cost)
    @profit_analysis[:total_revenue] = assignments.sum(&:actual_revenue)
    @profit_analysis[:gross_profit] = @profit_analysis[:total_revenue] - @profit_analysis[:total_cost]
    @profit_analysis[:profit_margin] = @profit_analysis[:total_revenue] > 0 ? 
      (@profit_analysis[:gross_profit] / @profit_analysis[:total_revenue] * 100).round(2) : 0
    
    # Daily profit trend
    @profit_analysis[:daily_profits] = (@start_date..@end_date).map do |date|
      daily_assignments = assignments.select { |a| a.date == date }
      daily_cost = daily_assignments.sum(&:actual_cost)
      daily_revenue = daily_assignments.sum(&:actual_revenue)
      {
        date: date.strftime('%Y-%m-%d'),
        cost: daily_cost,
        revenue: daily_revenue,
        profit: daily_revenue - daily_cost
      }
    end
    
    # Vendor profit breakdown
    @profit_analysis[:vendor_profits] = assignments.group_by(&:vendor_name).map do |vendor, vendor_assignments|
      vendor_cost = vendor_assignments.sum(&:actual_cost)
      vendor_revenue = vendor_assignments.sum(&:actual_revenue)
      {
        vendor: vendor,
        cost: vendor_cost,
        revenue: vendor_revenue,
        profit: vendor_revenue - vendor_cost,
        margin: vendor_revenue > 0 ? ((vendor_revenue - vendor_cost) / vendor_revenue * 100).round(2) : 0
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
    delivery_data = current_user.delivery_assignments
                               .joins(:product)
                               .where(scheduled_date: @date)
                               .where(products: { name: ['Milk', 'milk', 'MILK'] })
    
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
      
      daily_delivered = current_user.delivery_assignments
                                   .joins(:product)
                                   .where(scheduled_date: date)
                                   .where(products: { name: ['Milk', 'milk', 'MILK'] })
                                   .sum(:quantity) || 0
      
      {
        date: date.strftime('%Y-%m-%d'),
        purchased: daily_purchased,
        delivered: daily_delivered,
        remaining: daily_purchased - daily_delivered
      }
    end
  end

  private

  def calculate_main_kpis(start_date, end_date)
    assignments = current_user.procurement_assignments.for_date_range(start_date, end_date)
    
    {
      total_milk_purchased: assignments.sum(:actual_quantity),
      total_cost: assignments.sum(&:actual_cost),
      total_revenue: assignments.sum(&:actual_revenue),
      gross_profit: assignments.sum(&:actual_profit),
      active_vendors: assignments.distinct.count(:vendor_name),
      completion_rate: assignments.completion_rate_for_period(start_date, end_date),
      average_buying_price: assignments.with_actual_quantity.average(:buying_price)&.round(2) || 0,
      profit_margin: calculate_profit_margin(assignments)
    }
  end

  def calculate_profit_margin(assignments)
    total_cost = assignments.sum(&:actual_cost)
    total_revenue = assignments.sum(&:actual_revenue)
    
    return 0 if total_cost.zero?
    ((total_revenue - total_cost) / total_cost * 100).round(2)
  end

  def generate_daily_chart_data(start_date, end_date)
    assignments = current_user.procurement_assignments.for_date_range(start_date, end_date)
    
    (start_date..end_date).map do |date|
      daily_assignments = assignments.select { |a| a.date == date }
      {
        date: date.strftime('%Y-%m-%d'),
        planned_quantity: daily_assignments.sum(&:planned_quantity),
        actual_quantity: daily_assignments.sum { |a| a.actual_quantity || 0 },
        cost: daily_assignments.sum(&:actual_cost),
        revenue: daily_assignments.sum(&:actual_revenue),
        profit: daily_assignments.sum(&:actual_profit)
      }
    end
  end

  def generate_vendor_chart_data(start_date, end_date)
    current_user.procurement_assignments
               .for_date_range(start_date, end_date)
               .group_by(&:vendor_name)
               .map do |vendor, assignments|
      {
        vendor: vendor,
        quantity: assignments.sum { |a| a.actual_quantity || 0 },
        cost: assignments.sum(&:actual_cost),
        revenue: assignments.sum(&:actual_revenue),
        profit: assignments.sum(&:actual_profit)
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
    # Procurement data
    total_purchased = current_user.procurement_assignments
                                 .for_date_range(start_date, end_date)
                                 .sum(:actual_quantity)
    
    # Delivery data
    total_delivered = current_user.delivery_assignments
                                 .joins(:product)
                                 .where(scheduled_date: start_date..end_date)
                                 .where(products: { name: ['Milk', 'milk', 'MILK'] })
                                 .sum(:quantity) || 0
    
    {
      purchased: total_purchased,
      delivered: total_delivered,
      remaining: total_purchased - total_delivered,
      utilization_rate: total_purchased > 0 ? (total_delivered.to_f / total_purchased * 100).round(2) : 0
    }
  end

  def calculate_vendor_performance(start_date, end_date)
    current_user.procurement_assignments
               .for_date_range(start_date, end_date)
               .group_by(&:vendor_name)
               .map do |vendor, assignments|
      {
        vendor: vendor,
        reliability: assignments.empty? ? 0 : (assignments.completed.count.to_f / assignments.count * 100).round(2),
        average_quantity: assignments.with_actual_quantity.average(:actual_quantity)&.round(2) || 0,
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
    # Add your authentication logic here
  end
end