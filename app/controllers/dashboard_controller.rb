class DashboardController < ApplicationController
  def index
    @total_customers = Customer.count
    @total_products = Product.count
    @pending_deliveries = DeliveryAssignment.where(status: 'pending').count
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
    # Today's stats
    today_assignments = DeliveryAssignment.joins(:product)
                                         .where(status: 'completed', scheduled_date: date)

    @total_delivered_today = {
      count: today_assignments.count,
      total_amount: today_assignments.sum(&:final_amount),
      total_liters: today_assignments.joins(:product).where(products: { unit_type: 'liters' }).sum(:quantity),
      milk_products_count: today_assignments.joins(:product).where("products.name ILIKE '%milk%'").count
    }

    # Monthly stats
    month_start = date.beginning_of_month
    month_end = date.end_of_month

    monthly_assignments = DeliveryAssignment.joins(:product)
                                           .where(status: 'completed')
                                           .where(completed_at: month_start..month_end)

    @total_delivered_monthly = {
      count: monthly_assignments.count,
      total_amount: monthly_assignments.sum(&:final_amount),
      total_liters: monthly_assignments.joins(:product).where(products: { unit_type: 'liters' }).sum(:quantity),
      milk_products_count: monthly_assignments.joins(:product).where("products.name ILIKE '%milk%'").count
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

    # Get all assignments for the week
    assignments = DeliveryAssignment.joins(:product)
                                   .where(status: 'completed')
                                   .where(scheduled_date: start_date..end_date)
                                   .includes(:product)

    # Group by date
    daily_data = assignments.group_by { |assignment| assignment.scheduled_date.to_date }

    # Convert to required format
    (start_date.to_date..end_date.to_date).map do |date|
      day_assignments = daily_data[date] || []
      {
        date: date.to_s,
        count: day_assignments.count,
        total_amount: day_assignments.sum(&:final_amount)
      }
    end
  end

  def get_top_delivered_products(date)
    # Get top 5 products by delivery count for last 30 days
    end_date = date
    start_date = date - 29.days

    # Use Rails query and group in Ruby to avoid SQL issues
    assignments = DeliveryAssignment.joins(:product)
                                   .where(status: 'completed')
                                   .where(scheduled_date: start_date..end_date)
                                   .includes(:product)

    # Group by product and calculate totals
    product_stats = assignments.group_by(&:product).map do |product, product_assignments|
      {
        name: product.name,
        unit_type: product.unit_type,
        total_delivered: product_assignments.sum(&:quantity),
        total_revenue: product_assignments.sum(&:final_amount)
      }
    end

    # Sort by total delivered and take top 5
    product_stats.sort_by { |p| -p[:total_delivered] }.first(5).map do |stats|
      OpenStruct.new(stats)
    end
  end

end