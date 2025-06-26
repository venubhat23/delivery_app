class DashboardController < ApplicationController
  def index
    @total_customers = Customer.count
    @total_products = Product.count
    @pending_deliveries = Delivery.where(status: 'pending').count
    @total_invoices = Invoice.count
    
    # Additional data for dynamic sections
    @top_products = Product.order(:name).limit(5)
    @recent_customers = Customer.order(created_at: :desc).limit(5)
  end
end