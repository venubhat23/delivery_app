class PurchaseInvoicesController < ApplicationController
  before_action :set_purchase_invoice, only: [:show, :edit, :update, :destroy, :mark_as_paid, :download_pdf]
  
  def index
    @purchase_invoices = PurchaseInvoice.includes(:purchase_invoice_items, :purchase_products)
    @purchase_invoices = @purchase_invoices.where(invoice_type: params[:type]) if params[:type].present?
    @purchase_invoices = @purchase_invoices.where(status: params[:status]) if params[:status].present?
    @purchase_invoices = @purchase_invoices.order(created_at: :desc)
    
    @total_sales = @purchase_invoices.sales.sum(:total_amount)
    @total_purchases = @purchase_invoices.purchases.sum(:total_amount)
    @unpaid_amount = @purchase_invoices.unpaid.sum(:balance_amount)
  end
  
  def show
  end
  
  def new
    @purchase_invoice = PurchaseInvoice.new
    @purchase_invoice.invoice_type = params[:type] || 'purchase'
    @purchase_invoice.invoice_date = Date.current
    @purchase_invoice.payment_terms = 30
    @purchase_products = PurchaseProduct.all
  end
  
  def create
    @purchase_invoice = PurchaseInvoice.new(purchase_invoice_params)
    
    if @purchase_invoice.save
      create_invoice_items
      @purchase_invoice.calculate_totals
      @purchase_invoice.save!
      
      redirect_to @purchase_invoice, notice: "#{@purchase_invoice.invoice_type.capitalize} invoice was successfully created."
    else
      @purchase_products = PurchaseProduct.all
      render :new
    end
  end
  
  def edit
    @purchase_products = PurchaseProduct.all
  end
  
  def update
    if @purchase_invoice.update(purchase_invoice_params)
      update_invoice_items
      @purchase_invoice.calculate_totals
      @purchase_invoice.save!
      
      redirect_to @purchase_invoice, notice: 'Invoice was successfully updated.'
    else
      @purchase_products = PurchaseProduct.all
      render :edit
    end
  end
  
  def destroy
    @purchase_invoice.destroy
    redirect_to purchase_invoices_path, notice: 'Invoice was successfully deleted.'
  end
  
  def mark_as_paid
    @purchase_invoice.mark_as_paid!
    redirect_to @purchase_invoice, notice: 'Invoice marked as paid.'
  end
  
  def download_pdf
    respond_to do |format|
      format.pdf do
        render pdf: "invoice_#{@purchase_invoice.invoice_number}",
               template: 'purchase_invoices/pdf',
               layout: 'pdf'
      end
    end
  end
  
  def profit_analysis
    @sales_invoices = PurchaseInvoice.sales.includes(:purchase_invoice_items, :purchase_products)
    @total_revenue = @sales_invoices.sum(:total_amount)
    @total_profit = @sales_invoices.sum(&:profit_amount)
    @profit_margin = @total_revenue > 0 ? (@total_profit / @total_revenue * 100).round(2) : 0
  end
  
  def sales_analysis
    @sales_data = PurchaseInvoice.sales.group(:party_name).sum(:total_amount)
    @monthly_sales = PurchaseInvoice.sales.group_by_month(:invoice_date).sum(:total_amount)
  end
  
  private
  
  def set_purchase_invoice
    @purchase_invoice = PurchaseInvoice.find(params[:id])
  end
  
  def purchase_invoice_params
    params.require(:purchase_invoice).permit(:invoice_type, :party_name, :invoice_date, 
                                           :payment_terms, :discount_amount, :notes, :amount_paid)
  end
  
  def create_invoice_items
    return unless params[:items].present?
    
    params[:items].each do |item_params|
      next if item_params[:purchase_product_id].blank?
      
      @purchase_invoice.purchase_invoice_items.create!(
        purchase_product_id: item_params[:purchase_product_id],
        quantity: item_params[:quantity],
        price: item_params[:price],
        tax_rate: item_params[:tax_rate] || 0,
        discount: item_params[:discount] || 0
      )
    end
  end
  
  def update_invoice_items
    @purchase_invoice.purchase_invoice_items.destroy_all
    create_invoice_items
  end
end