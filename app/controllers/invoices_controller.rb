# app/controllers/invoices_controller.rb
class InvoicesController < ApplicationController
  before_action :set_invoice, only: [:show, :edit, :update, :destroy, :mark_as_paid]
  before_action :set_customers, only: [:index, :new, :create, :generate]
  
  def index
    @invoices = Invoice.includes(:customer)
    
    # Apply filters
    @invoices = @invoices.by_customer(params[:customer_id]) if params[:customer_id].present?
    @invoices = @invoices.where(status: params[:status]) if params[:status].present?
    
    # Date filter
    if params[:from_date].present? || params[:to_date].present?
      @invoices = @invoices.by_date_range(params[:from_date], params[:to_date])
    end
    
    # Month filter
    if params[:month].present? && params[:year].present?
      @invoices = @invoices.by_month(params[:month], params[:year])
    end
    
    # Search
    @invoices = @invoices.search_by_number_or_customer(params[:search]) if params[:search].present?
    
    @invoices = @invoices.order(created_at: :desc)
    
    # Get invoice statistics
    @stats = Invoice.invoice_stats
    
    respond_to do |format|
      format.html
      format.json { render json: @invoices }
    end
  end
  
  def show
    @invoice_items = @invoice.invoice_items.includes(:product)
  end
  
  def new
    @invoice = Invoice.new
    @invoice.invoice_items.build
  end
  
  def create
    @invoice = Invoice.new(invoice_params)
    @invoice.invoice_date = Date.current if @invoice.invoice_date.blank?
    @invoice.due_date = @invoice.invoice_date + 10.days if @invoice.due_date.blank?
    @invoice.status = 'pending' if @invoice.status.blank?
    
    if @invoice.save
      redirect_to @invoice, notice: 'Invoice was successfully created.'
    else
      @invoice.invoice_items.build if @invoice.invoice_items.empty?
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @invoice.update(invoice_params)
      redirect_to @invoice, notice: 'Invoice was successfully updated.'
    else
      render :edit
    end
  end
  
  def destroy
    @invoice.destroy
    redirect_to invoices_url, notice: 'Invoice was successfully deleted.'
  end
  
  # New action for generating invoices
  def generate
    if request.post?
      customer_id = params[:customer_id]
      month = params[:month].to_i
      year = params[:year].to_i
      
      if customer_id.present? && month > 0 && year > 0
        result = Invoice.generate_invoice_for_customer_month(customer_id, month, year)
        
        if result[:success]
          redirect_to result[:invoice], notice: result[:message]
        else
          flash[:alert] = result[:message]
          redirect_to generate_invoices_path
        end
      else
        flash[:alert] = "Please select customer, month and year"
        redirect_to generate_invoices_path
      end
    else
      # Show the generation form
      @current_month = Date.current.month
      @current_year = Date.current.year
      @months = (1..12).map { |m| [Date::MONTHNAMES[m], m] }
      @years = (2020..Date.current.year + 1).to_a.reverse
      
      # Get preview data if customer and month are selected
      if params[:customer_id].present? && params[:month].present? && params[:year].present?
        @preview_data = DeliveryAssignment.monthly_summary_for_customer(
          params[:customer_id].to_i, 
          params[:month].to_i, 
          params[:year].to_i
        )
      end
    end
  end
  
  # AJAX action for getting monthly preview
  def monthly_preview
    customer_id = params[:customer_id].to_i
    month = params[:month].to_i
    year = params[:year].to_i
    
    if customer_id > 0 && month > 0 && year > 0
      @preview_data = DeliveryAssignment.monthly_summary_for_customer(customer_id, month, year)
      render partial: 'monthly_preview', locals: { preview_data: @preview_data }
    else
      render json: { error: 'Invalid parameters' }, status: 400
    end
  end
  
 

    def mark_as_paid
      @invoice = Invoice.find(params[:id])
      @invoice.update(status: 'paid', paid_at: Time.current)

      redirect_to @invoice, notice: 'Invoice marked as paid.'
    end

  
  private
  
  def set_invoice
    @invoice = Invoice.find(params[:id])
  end
  
  def set_customers
    @customers = Customer.includes(:user).order(:name)
  end
  
  def invoice_params
    params.require(:invoice).permit(
      :customer_id, :invoice_date, :due_date, :status, :notes,
      invoice_items_attributes: [:id, :product_id, :quantity, :unit_price, :_destroy]
    )
  end
end