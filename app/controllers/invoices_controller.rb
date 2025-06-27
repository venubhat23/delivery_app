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
  
  # def show
  #   @invoice_items = @invoice.invoice_items.includes(:product)
  #   @customer = @invoice.customer
  # end

def show
  @invoice_items = @invoice.invoice_items.includes(:product)
  @customer = @invoice.customer
  
  respond_to do |format|
    format.html
    format.pdf do
      render pdf: "invoice_#{@invoice.id}",
             template: 'invoices/show',  # Don't specify .html.erb or .pdf.erb
             layout: false,
             page_size: 'A4',
             margin: { top: 5, bottom: 5, left: 5, right: 5 },
             encoding: 'UTF-8'
    end
  end
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
  
  # NEW: Generate monthly invoices for all customers
  def generate_monthly_for_all
    month = params[:month]&.to_i || Date.current.month
    year = params[:year]&.to_i || Date.current.year
    
    begin
      results = Invoice.generate_monthly_invoices_for_all_customers(month, year)
      success_count = 0
      failure_count = 0
      errors = []
      
      results.each do |result|
        if result[:result][:success]
          success_count += 1
          # Send WhatsApp message for successful invoice
          begin
            send_whatsapp_invoice(result[:result][:invoice])
          rescue => e
            Rails.logger.error "WhatsApp sending failed for invoice #{result[:result][:invoice].id}: #{e.message}"
          end
        else
          failure_count += 1
          errors << "#{result[:customer].name}: #{result[:result][:message]}"
        end
      end
      
      if success_count > 0
        flash[:notice] = "Successfully generated #{success_count} invoices and sent WhatsApp notifications."
      end
      
      if failure_count > 0
        flash[:alert] = "#{failure_count} invoices could not be generated. #{errors.join(', ')}"
      end
      
      if success_count == 0 && failure_count == 0
        flash[:alert] = "No customers with completed deliveries found for #{Date::MONTHNAMES[month]} #{year}"
      end
      
    rescue => e
      Rails.logger.error "Error generating monthly invoices: #{e.message}"
      flash[:alert] = "Error occurred while generating invoices: #{e.message}"
    end
    
    # Always redirect back to invoices index
    redirect_to invoices_path
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
  
  # Existing action for generating single customer invoice
  def generate
    if request.post?
      customer_id = params[:customer_id]
      month = params[:month].to_i
      year = params[:year].to_i
      
      if customer_id.present? && month > 0 && year > 0
        result = Invoice.generate_invoice_for_customer_month(customer_id, month, year)
        
        if result[:success]
          # Send WhatsApp message for single invoice
          begin
            send_whatsapp_invoice(result[:invoice])
            redirect_to result[:invoice], notice: "#{result[:message]} WhatsApp notification sent successfully."
          rescue => e
            Rails.logger.error "WhatsApp sending failed: #{e.message}"
            redirect_to result[:invoice], notice: "#{result[:message]} (WhatsApp notification failed)"
          end
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
    redirect_to invoices_path, notice: 'Invoice marked as paid.'
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

  # NEW: Send WhatsApp invoice notification
  def send_whatsapp_invoice(invoice)
    # return unless invoice&.customer&.phone_number.present?
    
    whatsapp_service = WhatsappService.new
    
    # Create personalized message
    message = create_invoice_message(invoice)
    
    # PDF URL (using the dummy PDF you provided)
    pdf_url = "https://conasems-ava-prod.s3.sa-east-1.amazonaws.com/aulas/ava/dummy-1641923583.pdf"
    # Send WhatsApp message with PDF
    whatsapp_service.send_pdf(invoice.customer.phone_number,pdf_url,message)
    
    Rails.logger.info "WhatsApp invoice sent to #{invoice.customer.name} (#{invoice.customer.phone_number})"
  end
  
  # NEW: Create personalized invoice message
  def create_invoice_message(invoice)
    month_year = invoice.invoice_date.strftime("%B %Y")
    formatted_amount = "₹#{ActionController::Base.helpers.number_with_delimiter(invoice.total_amount)}"
    
    message = <<~MSG
      Hello #{invoice.customer.name}! 👋
      
      Your #{month_year} invoice is ready! 📋
      
      📄 Invoice #: #{invoice.formatted_number}
      💰 Total Amount: #{formatted_amount}
      📅 Due Date: #{invoice.due_date.strftime('%d %B %Y')}
      
      Please find your detailed invoice attached as PDF. 
      
      Thank you for your continued business! 🙏
      
      For any queries, please contact us.
    MSG
    
    message.strip

  end


  def render_pdf
    # Option 1: Using WickedPDF (most common)
    if defined?(WickedPdf)
      render pdf: "invoice_#{@invoice.id}",
             template: 'invoices/show.html.erb',
             layout: false,
             page_size: 'A4',
             margin: { top: 5, bottom: 5, left: 5, right: 5 },
             encoding: 'UTF-8',
             show_as_html: params[:debug].present?,
             footer: {
               right: 'Page [page] of [topage]',
               font_size: 8
             }
    
    # Option 2: Using Prawn (if you prefer pure Ruby PDF generation)
    elsif defined?(Prawn)
      pdf_content = generate_pdf_with_prawn
      send_data pdf_content, 
                filename: "invoice_#{@invoice.id}.pdf", 
                type: 'application/pdf', 
                disposition: 'attachment'
    
    # Option 3: Using Grover (Chrome headless)
    elsif defined?(Grover)
      html_content = render_to_string(template: 'invoices/show.html.erb', layout: false)
      pdf_content = Grover.new(html_content, format: 'A4', margin: '0.5in').to_pdf
      send_data pdf_content, 
                filename: "invoice_#{@invoice.id}.pdf", 
                type: 'application/pdf', 
                disposition: 'attachment'
    
    # Fallback: Render as HTML if no PDF gem is available
    else
      render template: 'invoices/show.html.erb', layout: false
    end
  end
  
  def generate_pdf_with_prawn
    Prawn::Document.new do |pdf|
      # Add your Prawn PDF generation logic here
      pdf.text "Invoice ##{@invoice.id}", size: 20, style: :bold
      pdf.move_down 20
      
      pdf.text "Customer: #{@invoice.customer.name}"
      pdf.text "Date: #{@invoice.invoice_date.strftime('%d/%m/%Y')}"
      pdf.text "Due Date: #{@invoice.due_date.strftime('%d/%m/%Y')}"
      pdf.move_down 20
      
      # Add invoice items table
      table_data = [['Product', 'Quantity', 'Rate', 'Amount']]
      @invoice_items.each do |item|
        table_data << [
          item.product&.name || 'Product',
          item.quantity.to_s,
          "₹#{item.unit_price}",
          "₹#{item.total_price || (item.quantity * item.unit_price)}"
        ]
      end
      
      pdf.table(table_data, header: true, width: pdf.bounds.width) do
        row(0).font_style = :bold
        columns(1..3).align = :right
      end
      
      pdf.move_down 20
      pdf.text "Total: ₹#{@invoice.total_amount}", size: 14, style: :bold, align: :right
    end.render
  end
end