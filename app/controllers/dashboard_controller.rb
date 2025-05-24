class DashboardController < ApplicationController
  def index
    @total_customers = Customer.count
    @total_products = Product.count
    @pending_deliveries = Delivery.where(status: 'pending').count
    @total_invoices = Invoice.count
  end
end
