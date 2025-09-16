class DashboardController < ApplicationController
  def index
    @total_customers = Customer.count
    @total_products = Product.count
    @pending_deliveries = Delivery.where(status: 'pending').count
    @total_invoices = Invoice.count
    
    # Additional data for dynamic sections
    @top_products = Product.order(:name).limit(5)
    @recent_customers = Customer.order(created_at: :desc).limit(5)
    
    # Total Delivered Milk Supply Analytics
    calculate_delivery_analytics
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
    # Optimize with single queries using SQL aggregation
    date_range = date.beginning_of_day..date.end_of_day

    # Use find_by_sql approach to avoid exec_query issues
    sql = <<-SQL
      SELECT
        COUNT(*) as count,
        SUM(COALESCE(final_amount_after_discount, products.price * delivery_assignments.quantity)) as total_amount,
        SUM(CASE WHEN products.unit_type = 'liters' THEN delivery_assignments.quantity ELSE 0 END) as total_liters,
        COUNT(CASE WHEN categories.name ILIKE '%milk%' OR products.name ILIKE '%milk%' THEN 1 END) as milk_products_count
      FROM delivery_assignments
      INNER JOIN products ON products.id = delivery_assignments.product_id
      LEFT JOIN categories ON products.category_id = categories.id
      WHERE delivery_assignments.status = 'completed'
      AND delivery_assignments.scheduled_date = '#{date}'
    SQL

    result = ActiveRecord::Base.connection.select_one(sql)
    today_stats = result

    @total_delivered_today = {
      count: today_stats&.[]('count')&.to_i || 0,
      total_amount: today_stats&.[]('total_amount')&.to_f || 0,
      total_liters: today_stats&.[]('total_liters')&.to_f || 0,
      milk_products_count: today_stats&.[]('milk_products_count')&.to_i || 0
    }

    # Monthly stats with raw SQL
    month_start = date.beginning_of_month
    month_end = date.end_of_month

    monthly_sql = <<-SQL
      SELECT
        COUNT(*) as count,
        SUM(COALESCE(final_amount_after_discount, products.price * delivery_assignments.quantity)) as total_amount,
        SUM(CASE WHEN products.unit_type = 'liters' THEN delivery_assignments.quantity ELSE 0 END) as total_liters,
        COUNT(CASE WHEN categories.name ILIKE '%milk%' OR products.name ILIKE '%milk%' THEN 1 END) as milk_products_count
      FROM delivery_assignments
      INNER JOIN products ON products.id = delivery_assignments.product_id
      LEFT JOIN categories ON products.category_id = categories.id
      WHERE delivery_assignments.status = 'completed'
      AND delivery_assignments.completed_at BETWEEN '#{month_start}' AND '#{month_end}'
    SQL

    monthly_stats = ActiveRecord::Base.connection.select_one(monthly_sql)

    @total_delivered_monthly = {
      count: monthly_stats&.[]('count')&.to_i || 0,
      total_amount: monthly_stats&.[]('total_amount')&.to_f || 0,
      total_liters: monthly_stats&.[]('total_liters')&.to_f || 0,
      milk_products_count: monthly_stats&.[]('milk_products_count')&.to_i || 0
    }

    # Optimized weekly data calculation
    @weekly_delivery_data = calculate_weekly_delivery_data(date)

    # Optimized top products calculation
    @top_delivered_products = get_top_delivered_products(date)
  end

  # Optimized helper methods for analytics
  def calculate_weekly_delivery_data(date)
    # Get data for 7 days ending on the specified date
    end_date = date
    start_date = date - 6.days

    DeliveryAssignment.unscoped
                     .where(status: 'completed')
                     .joins(:product)
                     .where(scheduled_date: start_date..end_date)
                     .group('DATE(scheduled_date)')
                     .order('DATE(scheduled_date)')
                     .select(
                       'DATE(scheduled_date) as date',
                       'COUNT(*) as count',
                       'SUM(COALESCE(final_amount_after_discount, products.price * delivery_assignments.quantity)) as total_amount'
                     ).map do |day_data|
      {
        date: day_data.date,
        count: day_data.count,
        total_amount: day_data.total_amount&.to_f || 0
      }
    end
  end

  def get_top_delivered_products(date)
    # Get top 5 products by delivery count for last 30 days
    end_date = date
    start_date = date - 29.days

    DeliveryAssignment.unscoped
                     .where(status: 'completed')
                     .joins(:product)
                     .where(scheduled_date: start_date..end_date)
                     .group('products.id, products.name, products.unit_type')
                     .order('SUM(delivery_assignments.quantity) DESC')
                     .limit(5)
                     .select(
                       'products.id',
                       'products.name',
                       'products.unit_type',
                       'SUM(delivery_assignments.quantity) as total_delivered',
                       'SUM(COALESCE(final_amount_after_discount, products.price * delivery_assignments.quantity)) as total_revenue'
                     ).map do |product_data|
      OpenStruct.new(
        name: product_data.name,
        unit_type: product_data.unit_type,
        total_delivered: product_data.total_delivered&.to_f || 0,
        total_revenue: product_data.total_revenue&.to_f || 0
      )
    end
  end

end