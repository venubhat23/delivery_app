
# app/controllers/sales_invoices_controller.rb
class SalesInvoicesController < ApplicationController
  before_action :set_sales_invoice, only: [:show, :edit, :update, :destroy, :mark_as_paid, :download_pdf]
  
  def index
    @sales_invoices = SalesInvoice.all
    
    # Apply filters
    @sales_invoices = @sales_invoices.by_status(params[:status]) if params[:status].present?
    @sales_invoices = @sales_invoices.by_customer(params[:customer]) if params[:customer].present?
    
    if params[:start_date].present? && params[:end_date].present?
      @sales_invoices = @sales_invoices.by_date_range(params[:start_date], params[:end_date])
    end
    
    @sales_invoices = @sales_invoices.order(created_at: :desc)
    
    # Calculate summary data
    @total_invoices = @sales_invoices.count
    @total_revenue = @sales_invoices.where(status: ['paid', 'partially_paid']).sum(:amount_paid)
    @pending_amount = @sales_invoices.where(status: ['pending', 'partially_paid']).sum(:balance_amount)
    @overdue_count = @sales_invoices.select(&:overdue?).count
  end
  
  def show
  end
  
  def new
    @sales_invoice = SalesInvoice.new
    @sales_invoice.sales_invoice_items.build
    @sales_products = SalesProduct.all.order(:name)
  end
  
  def create
    @sales_invoice = SalesInvoice.new(sales_invoice_params)
    @sales_invoice.invoice_date = Date.current if @sales_invoice.invoice_date.blank?
    @sales_invoice.due_date = @sales_invoice.invoice_date + @sales_invoice.payment_terms.days if @sales_invoice.due_date.blank?
    
    if @sales_invoice.save
      redirect_to @sales_invoice, notice: 'Sales invoice was successfully created.'
    else
      @sales_products = SalesProduct.all.order(:name)
      render :new
    end
  end
  
  def edit
    @sales_products = SalesProduct.all.order(:name)
  end
  
  def update
    if @sales_invoice.update(sales_invoice_params)
      redirect_to @sales_invoice, notice: 'Sales invoice was successfully updated.'
    else
      @sales_products = SalesProduct.all.order(:name)
      render :edit
    end
  end
  
  def destroy
    @sales_invoice.destroy
    redirect_to sales_invoices_path, notice: 'Sales invoice was successfully deleted.'
  end
  
  def mark_as_paid
    @sales_invoice.mark_as_paid!
    redirect_to @sales_invoice, notice: 'Invoice marked as paid successfully.'
  end
  
  def download_pdf
    # PDF generation logic here
    redirect_to @sales_invoice, notice: 'PDF generation feature coming soon.'
  end
  
  def profit_analysis
    @start_date = params[:start_date]&.to_date || 1.month.ago
    @end_date = params[:end_date]&.to_date || Date.current
    
    @total_revenue = SalesInvoice.revenue_for_period(@start_date, @end_date)
    @total_profit = SalesInvoice.profit_for_period(@start_date, @end_date)
    @profit_margin = @total_revenue > 0 ? (@total_profit / @total_revenue * 100).round(2) : 0
    
    # Product-wise profit analysis
    @product_profits = SalesInvoiceItem.joins(:sales_invoice, :sales_product)
                                      .where(sales_invoices: { 
                                        invoice_date: @start_date..@end_date,
                                        status: ['paid', 'partially_paid']
                                      })
                                      .group('sales_products.name')
                                      .select('sales_products.name, 
                                              SUM(sales_invoice_items.quantity) as total_quantity,
                                              SUM(sales_invoice_items.amount) as total_revenue')
                                      .order('total_revenue DESC')
  end
  
  def sales_analysis
    @start_date = params[:start_date]&.to_date || 1.month.ago
    @end_date = params[:end_date]&.to_date || Date.current
    
    @sales_by_month = SalesInvoice.where(invoice_date: @start_date..@end_date, status: ['paid', 'partially_paid'])
                                 .group("DATE_TRUNC('month', invoice_date)")
                                 .sum(:amount_paid)
    
    @top_customers = SalesInvoice.where(invoice_date: @start_date..@end_date, status: ['paid', 'partially_paid'])
                                .group(:customer_name)
                                .sum(:amount_paid)
                                .sort_by { |_, amount| -amount }
                                .first(10)
  end
  
  private
  
  def set_sales_invoice
    @sales_invoice = SalesInvoice.find(params[:id])
  end
  
  def sales_invoice_params
    params.require(:sales_invoice).permit(:invoice_type, :customer_name, :invoice_date, 
                                         :due_date, :payment_terms, :notes, :amount_paid,
                                         sales_invoice_items_attributes: [:id, :sales_product_id, 
                                         :quantity, :price, :tax_rate, :discount, :_destroy])
  end
end

