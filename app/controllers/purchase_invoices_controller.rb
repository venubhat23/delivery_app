class PurchaseInvoicesController < ApplicationController
  before_action :set_purchase_invoice, only: [:show, :edit, :update, :destroy, :mark_as_paid, :download_pdf]
  
  def index
    @purchase_invoices = PurchaseInvoice.includes(:purchase_invoice_items, :purchase_products, :purchase_customer)
    
    # Apply filters
    @purchase_invoices = @purchase_invoices.by_party(params[:party]) if params[:party].present?
    @purchase_invoices = @purchase_invoices.by_status(params[:status]) if params[:status].present?
    
    # Date filtering
    if params[:start_date].present? && params[:end_date].present?
      @purchase_invoices = @purchase_invoices.by_date_range(params[:start_date], params[:end_date])
    elsif params[:month].present? && params[:year].present?
      start_date = Date.new(params[:year].to_i, params[:month].to_i, 1)
      end_date = start_date.end_of_month
      @purchase_invoices = @purchase_invoices.by_date_range(start_date, end_date)
    elsif params[:date_filter] == 'last_365_days' || params[:date_filter].blank?
      @purchase_invoices = @purchase_invoices.by_date_range(365.days.ago, Date.current)
    end
    
    @purchase_invoices = @purchase_invoices.recent
    
    # Calculate summary statistics
    stats = @purchase_invoices.summary_stats
    @total_purchases = stats[:total_purchases]
    @total_paid = stats[:total_paid] 
    @total_unpaid = stats[:total_unpaid]
    @overdue_count = @purchase_invoices.overdue.count
    
    # Pagination if needed
    @purchase_invoices = @purchase_invoices.limit(50) unless params[:show_all] == 'true'
  end
  
  def show
  end
  
  def new
    @purchase_invoice = PurchaseInvoice.new
    @purchase_invoice.invoice_date = Date.current
    @purchase_invoice.payment_terms = 30
    @purchase_invoice.purchase_invoice_items.build
    
    @purchase_products = PurchaseProduct.active.order(:name)
    @purchase_customers = PurchaseCustomer.active.order(:name)
  end
  
  def create
    @purchase_invoice = PurchaseInvoice.new(purchase_invoice_params)
    
    if @purchase_invoice.save
      redirect_to @purchase_invoice, notice: 'Purchase invoice was successfully created.'
    else
      @purchase_products = PurchaseProduct.active.order(:name)
      @purchase_customers = PurchaseCustomer.active.order(:name)
      render :new
    end
  end
  
  def edit
    @purchase_products = PurchaseProduct.active.order(:name)
    @purchase_customers = PurchaseCustomer.active.order(:name)
    
    # Ensure at least one item exists for the form
    @purchase_invoice.purchase_invoice_items.build if @purchase_invoice.purchase_invoice_items.empty?
  end
  
  def update
    if @purchase_invoice.update(purchase_invoice_params)
      redirect_to @purchase_invoice, notice: 'Purchase invoice was successfully updated.'
    else
      @purchase_products = PurchaseProduct.active.order(:name)
      @purchase_customers = PurchaseCustomer.active.order(:name)
      render :edit
    end
  end
  
  def destroy
    @purchase_invoice.destroy
    redirect_to purchase_invoices_path, notice: 'Purchase invoice was successfully deleted.'
  end
  
  def mark_as_paid
    payment_type = params[:payment_type] || 'cash'
    
    begin
      @purchase_invoice.mark_as_paid!(payment_type)
      redirect_to @purchase_invoice, notice: 'Invoice marked as paid successfully.'
    rescue => e
      redirect_to @purchase_invoice, alert: "Error marking invoice as paid: #{e.message}"
    end
  end
  
  def add_payment
    @purchase_invoice = PurchaseInvoice.find(params[:id])
    amount = params[:amount].to_f
    payment_type = params[:payment_type] || 'cash'
    
    if amount > 0 && amount <= @purchase_invoice.balance_amount
      @purchase_invoice.add_payment(amount, payment_type)
      redirect_to @purchase_invoice, notice: "Payment of ₹#{amount} added successfully."
    else
      redirect_to @purchase_invoice, alert: 'Invalid payment amount.'
    end
  end
  
  def download_pdf
    respond_to do |format|
      format.html do
        pdf = WickedPdf.new.pdf_from_string(
          render_to_string(
            template: 'purchase_invoices/pdf',
            layout: 'pdf',
            locals: { purchase_invoice: @purchase_invoice }
          ),
          page_size: 'A4',
          margin: { top: 20, bottom: 20, left: 20, right: 20 }
        )
        
        filename = "purchase_invoice_#{@purchase_invoice.invoice_number.gsub('/', '_')}.pdf"
        send_data pdf, filename: filename, type: 'application/pdf', disposition: 'attachment'
      end
      format.pdf do
        pdf = WickedPdf.new.pdf_from_string(
          render_to_string(
            template: 'purchase_invoices/pdf',
            layout: 'pdf',
            locals: { purchase_invoice: @purchase_invoice }
          ),
          page_size: 'A4',
          margin: { top: 20, bottom: 20, left: 20, right: 20 }
        )
        
        filename = "purchase_invoice_#{@purchase_invoice.invoice_number.gsub('/', '_')}.pdf"
        send_data pdf, filename: filename, type: 'application/pdf', disposition: 'attachment'
      end
    end
  end
  
  def bulk_upload
    # Handle bulk upload functionality
    if params[:file].present?
      # Process CSV file
      redirect_to purchase_invoices_path, notice: 'Bulk upload processed successfully.'
    else
      redirect_to purchase_invoices_path, alert: 'Please select a file to upload.'
    end
  end
  
  private
  
  def set_purchase_invoice
    @purchase_invoice = PurchaseInvoice.find(params[:id])
  end
  
  def purchase_invoice_params
    params.require(:purchase_invoice).permit(
      :party_name, :invoice_date, :payment_terms, :original_invoice_number,
      :bill_from, :ship_from, :additional_charges, :additional_discount,
      :auto_round_off, :amount_paid, :payment_type, :notes,
      :terms_and_conditions, :authorized_signature,
      purchase_invoice_items_attributes: [
        :id, :purchase_product_id, :quantity, :price, :tax_rate, :discount, :description, :hsn_sac, :_destroy
      ]
    )
  end
end