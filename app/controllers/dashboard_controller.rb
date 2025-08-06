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
    # Get completed deliveries for the specified date
    @todays_deliveries = DeliveryAssignment.completed
                                          .for_date(date)
                                          .includes(:product, :customer)
    
    # Calculate specified date totals
    @total_delivered_today = {
      count: @todays_deliveries.count,
      total_amount: calculate_total_amount(@todays_deliveries),
      total_liters: calculate_total_liters(@todays_deliveries),
      milk_products_count: count_milk_products(@todays_deliveries)
    }
    
    # Get deliveries for the month containing the specified date
    month_start = date.beginning_of_month
    month_end = date.end_of_month
    
    @monthly_deliveries = DeliveryAssignment.completed
                                           .where(completed_at: month_start..month_end)
                                           .includes(:product, :customer)
    
    # Calculate monthly totals
    @total_delivered_monthly = {
      count: @monthly_deliveries.count,
      total_amount: calculate_total_amount(@monthly_deliveries),
      total_liters: calculate_total_liters(@monthly_deliveries),
      milk_products_count: count_milk_products(@monthly_deliveries)
    }
    
    # Get delivery analytics for the last 7 days from the specified date
    @weekly_delivery_data = calculate_weekly_delivery_data(date)
    
    # Get top delivered products for the last 30 days from the specified date
    @top_delivered_products = get_top_delivered_products(date)
  end

  def calculate_total_amount(deliveries)
    deliveries.sum { |delivery| delivery.total_amount }
  end

  def calculate_total_liters(deliveries)
    deliveries.joins(:product)
              .where(products: { unit_type: 'liters' })
              .sum(:quantity)
  end

  def count_milk_products(deliveries)
    deliveries.joins(:product)
              .joins('JOIN categories ON products.category_id = categories.id')
              .where('categories.name ILIKE ? OR products.name ILIKE ?', '%milk%', '%milk%')
              .count
  end

  def calculate_weekly_delivery_data(end_date = Date.current)
    data = []
    7.times do |i|
      date = end_date - i.days
      daily_deliveries = DeliveryAssignment.completed.for_date(date).includes(:product)
      
      data.unshift({
        date: date,
        day: date.strftime('%a'),
        count: daily_deliveries.count,
        amount: calculate_total_amount(daily_deliveries),
        liters: calculate_total_liters(daily_deliveries)
      })
    end
    data
  end

  def get_top_delivered_products(end_date = Date.current)
    start_date = end_date - 30.days
    
    DeliveryAssignment.completed
                     .where(completed_at: start_date..end_date)
                     .joins(:product)
                     .group('products.id, products.name, products.unit_type, products.price')
                     .select('products.*, SUM(delivery_assignments.quantity) as total_delivered, 
                             COUNT(delivery_assignments.id) as delivery_count,
                             SUM(delivery_assignments.quantity * products.price) as total_revenue')
                     .order('total_delivered DESC')
                     .limit(5)
  end
end