class Api::V1::DashboardController < Api::V1::BaseController
  def index
    render json: {
      data: {
        overview: overview_stats,
        recent_activities: recent_activities,
        delivery_stats: delivery_stats,
        revenue_stats: revenue_stats,
        charts: chart_data
      }
    }
  end
  
  private
  
  def overview_stats
    {
      total_customers: Customer.count,
      total_products: Product.count,
      active_delivery_people: User.where(role: 'delivery_person').count,
      pending_deliveries: DeliveryAssignment.pending.count,
      completed_deliveries_today: DeliveryAssignment.completed.where(completed_at: Date.current.beginning_of_day..Date.current.end_of_day).count,
      total_revenue_this_month: Invoice.where(created_at: Date.current.beginning_of_month..Date.current.end_of_month).sum(:total_amount),
      pending_invoices: Invoice.where(status: 'pending').count,
      low_stock_products: Product.low_stock.count
    }
  end
  
  def recent_activities
    activities = []
    
    # Recent customers
    recent_customers = Customer.recent.limit(5)
    recent_customers.each do |customer|
      activities << {
        type: 'customer_created',
        title: "New customer added: #{customer.name}",
        description: "Customer #{customer.name} was added to the system",
        timestamp: customer.created_at,
        icon: 'user-plus'
      }
    end
    
    # Recent deliveries
    recent_deliveries = DeliveryAssignment.includes(:customer, :product).order(created_at: :desc).limit(5)
    recent_deliveries.each do |delivery|
      activities << {
        type: 'delivery_assigned',
        title: "Delivery assigned: #{delivery.customer.name}",
        description: "#{delivery.product.name} scheduled for #{delivery.scheduled_date}",
        timestamp: delivery.created_at,
        icon: 'truck'
      }
    end
    
    # Recent invoices
    recent_invoices = Invoice.includes(:customer).order(created_at: :desc).limit(5)
    recent_invoices.each do |invoice|
      activities << {
        type: 'invoice_generated',
        title: "Invoice generated: #{invoice.invoice_number}",
        description: "Invoice for #{invoice.customer.name} - $#{invoice.total_amount}",
        timestamp: invoice.created_at,
        icon: 'file-text'
      }
    end
    
    activities.sort_by { |a| a[:timestamp] }.reverse.first(10)
  end
  
  def delivery_stats
    today = Date.current
    this_week = today.beginning_of_week..today.end_of_week
    this_month = today.beginning_of_month..today.end_of_month
    
    {
      today: {
        total: DeliveryAssignment.for_date(today).count,
        completed: DeliveryAssignment.completed.for_date(today).count,
        pending: DeliveryAssignment.pending.for_date(today).count,
        cancelled: DeliveryAssignment.cancelled.for_date(today).count
      },
      this_week: {
        total: DeliveryAssignment.where(scheduled_date: this_week).count,
        completed: DeliveryAssignment.completed.where(scheduled_date: this_week).count,
        pending: DeliveryAssignment.pending.where(scheduled_date: this_week).count
      },
      this_month: {
        total: DeliveryAssignment.where(scheduled_date: this_month).count,
        completed: DeliveryAssignment.completed.where(scheduled_date: this_month).count,
        pending: DeliveryAssignment.pending.where(scheduled_date: this_month).count
      }
    }
  end
  
  def revenue_stats
    this_month = Date.current.beginning_of_month..Date.current.end_of_month
    last_month = Date.current.last_month.beginning_of_month..Date.current.last_month.end_of_month
    
    this_month_revenue = Invoice.where(created_at: this_month).sum(:total_amount)
    last_month_revenue = Invoice.where(created_at: last_month).sum(:total_amount)
    
    growth_percentage = last_month_revenue > 0 ? ((this_month_revenue - last_month_revenue) / last_month_revenue * 100).round(2) : 0
    
    {
      this_month: this_month_revenue,
      last_month: last_month_revenue,
      growth_percentage: growth_percentage,
      total_pending: Invoice.where(status: 'pending').sum(:total_amount),
      total_paid: Invoice.where(status: 'paid').sum(:total_amount)
    }
  end
  
  def chart_data
    {
      daily_deliveries: daily_deliveries_chart,
      monthly_revenue: monthly_revenue_chart,
      product_distribution: product_distribution_chart,
      delivery_person_performance: delivery_person_performance_chart
    }
  end
  
  def daily_deliveries_chart
    data = {}
    (6.days.ago.to_date..Date.current).each do |date|
      completed = DeliveryAssignment.completed.where(completed_at: date.beginning_of_day..date.end_of_day).count
      pending = DeliveryAssignment.pending.for_date(date).count
      
      data[date.strftime('%Y-%m-%d')] = {
        completed: completed,
        pending: pending,
        total: completed + pending
      }
    end
    data
  end
  
  def monthly_revenue_chart
    data = {}
    (5.months.ago.to_date..Date.current).each do |date|
      month_start = date.beginning_of_month
      month_end = date.end_of_month
      revenue = Invoice.where(created_at: month_start..month_end).sum(:total_amount)
      
      data[date.strftime('%Y-%m')] = revenue
    end
    data
  end
  
  def product_distribution_chart
    Product.joins(:delivery_assignments)
           .group('products.name')
           .sum('delivery_assignments.quantity')
           .transform_keys { |name| name.truncate(20) }
  end
  
  def delivery_person_performance_chart
    User.where(role: 'delivery_person')
        .joins(:delivery_assignments)
        .where(delivery_assignments: { status: 'completed' })
        .group('users.name')
        .count
        .transform_keys { |name| name.truncate(15) }
  end
end