class DashboardController < ApplicationController
  def index
    # Cache basic counts for 5 minutes
    @total_customers = Rails.cache.fetch("dashboard_customers_count", expires_in: 5.minutes) do
      Customer.count
    end

    @total_products = Rails.cache.fetch("dashboard_products_count", expires_in: 5.minutes) do
      Product.count
    end

    @pending_deliveries = Rails.cache.fetch("dashboard_pending_deliveries", expires_in: 30.seconds) do
      DeliveryAssignment.where(status: 'pending').count
    end

    @total_invoices = Rails.cache.fetch("dashboard_invoices_count", expires_in: 5.minutes) do
      Invoice.count
    end

    # Cache top products for 10 minutes
    @top_products = Rails.cache.fetch("dashboard_top_products", expires_in: 10.minutes) do
      Product.order(:name).limit(5).to_a
    end

    # Cache recent customers for 2 minutes
    @recent_customers = Rails.cache.fetch("dashboard_recent_customers", expires_in: 2.minutes) do
      Customer.includes(:user, :delivery_person).order(created_at: :desc).limit(5).to_a
    end

    # Total Delivered Milk Supply Analytics
    calculate_delivery_analytics

    # Warm up cache in background if needed
    warm_up_cache_if_needed
  end

  def warm_up_cache_if_needed
    # Check if any critical cache keys are missing and warm them up
    today = Date.current
    cache_keys = [
      "dashboard_today_stats_#{today}",
      "dashboard_monthly_stats_#{today.year}_#{today.month}",
      "dashboard_weekly_data_#{today}"
    ]

    missing_keys = cache_keys.select { |key| Rails.cache.read(key).nil? }

    if missing_keys.any?
      # Trigger cache population in a way that doesn't block the response
      calculate_delivery_analytics_for_date(today, 'today')
    end
  end

  def delivery_analytics
    # AJAX endpoint for filtered delivery analytics
    @selected_date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @date_range = params[:range] || 'today'
    
    calculate_delivery_analytics_for_date(@selected_date, @date_range)
    
    render json: {
      date: @selected_date.strftime('%b %d, %Y'),
      range: @date_range,
      today_stats: @total_delivered_today,
      monthly_stats: @total_delivered_monthly,
      weekly_data: @weekly_delivery_data,
      top_products: @top_delivered_products.map do |product|
        {
          name: product.name,
          total_delivered: product.total_delivered,
          unit_type: product.unit_type,
          total_revenue: product.total_revenue.round(2)
        }
      end
    }
  end

  private

  def calculate_delivery_analytics
    today = Date.current
    calculate_delivery_analytics_for_date(today, 'today')
  end

  def calculate_delivery_analytics_for_date(date, range)
    # Cache today's stats for 10 minutes (more frequent updates for today)
    @total_delivered_today = Rails.cache.fetch("dashboard_today_stats_#{date}", expires_in: 10.minutes) do
      calculate_today_stats(date)
    end

    # Cache monthly stats for 30 minutes (intermediate frequency)
    month_key = "#{date.year}_#{date.month}"
    @total_delivered_monthly = Rails.cache.fetch("dashboard_monthly_stats_#{month_key}", expires_in: 30.minutes) do
      calculate_monthly_stats(date)
    end

    # Cache weekly data for 15 minutes
    @weekly_delivery_data = Rails.cache.fetch("dashboard_weekly_data_#{date}", expires_in: 15.minutes) do
      calculate_weekly_delivery_data(date)
    end

    # Cache top products for 1 hour (least frequent changes)
    @top_delivered_products = Rails.cache.fetch("dashboard_top_products_#{date}", expires_in: 1.hour) do
      get_top_delivered_products(date)
    end
  end

  def calculate_today_stats(date)
    # Use separate optimized queries to leverage indexes better
    base_assignments = DeliveryAssignment.where(status: 'completed', scheduled_date: date)

    # Get basic stats without joins first
    count = base_assignments.count
    total_amount = base_assignments.sum(:final_amount_after_discount)

    # Use separate queries for product-specific stats to leverage indexes
    total_liters = base_assignments.joins(:product)
                                  .where(products: { unit_type: 'liters' })
                                  .sum(:quantity)

    # Use more efficient query for milk products
    milk_products_count = base_assignments.joins(:product)
                                         .where("products.name ILIKE ?", '%milk%')
                                         .count

    {
      count: count,
      total_amount: total_amount,
      total_liters: total_liters,
      milk_products_count: milk_products_count
    }
  end

  def calculate_monthly_stats(date)
    month_start = date.beginning_of_month
    month_end = date.end_of_month

    # Use separate optimized queries to leverage indexes better
    base_assignments = DeliveryAssignment.where(status: 'completed')
                                        .where(completed_at: month_start..month_end)

    # Get basic stats without joins first
    count = base_assignments.count
    total_amount = base_assignments.sum(:final_amount_after_discount)

    # Use separate queries for product-specific stats to leverage indexes
    total_liters = base_assignments.joins(:product)
                                  .where(products: { unit_type: 'liters' })
                                  .sum(:quantity)

    # Use more efficient query for milk products
    milk_products_count = base_assignments.joins(:product)
                                         .where("products.name ILIKE ?", '%milk%')
                                         .count

    {
      count: count,
      total_amount: total_amount,
      total_liters: total_liters,
      milk_products_count: milk_products_count
    }
  end

  # Optimized helper methods for analytics
  def calculate_weekly_delivery_data(date)
    # Get data for 7 days ending on the specified date
    end_date = date
    start_date = date - 6.days

    # Use simpler aggregation query
    daily_stats = DeliveryAssignment.where(status: 'completed')
                                   .where(scheduled_date: start_date..end_date)
                                   .group(:scheduled_date)
                                   .count

    daily_amounts = DeliveryAssignment.where(status: 'completed')
                                     .where(scheduled_date: start_date..end_date)
                                     .group(:scheduled_date)
                                     .sum(:final_amount_after_discount)

    # Convert to required format
    (start_date.to_date..end_date.to_date).map do |day_date|
      {
        date: day_date.to_s,
        count: daily_stats[day_date] || 0,
        total_amount: daily_amounts[day_date] || 0
      }
    end
  end

  def get_top_delivered_products(date)
    # Get top 5 products by delivery count for last 30 days using database aggregation
    end_date = date
    start_date = date - 29.days

    # Use database aggregation for better performance
    product_stats = DeliveryAssignment.joins(:product)
                                     .where(status: 'completed')
                                     .where(scheduled_date: start_date..end_date)
                                     .group('products.id, products.name, products.unit_type')
                                     .select('products.name, products.unit_type,
                                             SUM(delivery_assignments.quantity) as total_delivered,
                                             SUM(delivery_assignments.final_amount_after_discount) as total_revenue')
                                     .order('total_delivered DESC')
                                     .limit(5)

    # Convert to required format
    product_stats.map do |stat|
      OpenStruct.new(
        name: stat.name,
        unit_type: stat.unit_type,
        total_delivered: stat.total_delivered.to_f,
        total_revenue: stat.total_revenue.to_f
      )
    end
  end

end