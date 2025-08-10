# app/controllers/invoices_controller.rb
class InvoicesController < ApplicationController
  before_action :set_invoice, only: [:show, :edit, :update, :destroy, :mark_as_paid, :convert_to_completed, :share_whatsapp]
  before_action :set_customers, only: [:index, :new, :create, :generate]
  skip_before_action :require_login, only: [:public_view, :public_download_pdf]
  
  def index
    # Optimize queries with proper includes to prevent N+1 queries
    @invoices = Invoice.includes(:customer, :invoice_items, :delivery_assignments)
    
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
    
    # Add pagination - 50 invoices per page
    @total_invoices = @invoices.count
    @invoices = @invoices.page(params[:page]).per(50)
    
    respond_to do |format|
      format.html
      format.json { 
        render json: @invoices.map { |invoice| 
          {
            id: invoice.id,
            invoice_number: invoice.formatted_number,
            customer_name: invoice.customer.name,
            customer_phone: invoice.customer.phone_number,
            invoice_date: invoice.invoice_date.strftime('%d %b %Y'),
            due_date: invoice.due_date.strftime('%d %b %Y'),
            total_amount: invoice.total_amount,
            status: invoice.status,
            invoice_type: invoice.invoice_type&.humanize || 'Manual',
            overdue: invoice.overdue?,
            days_overdue: invoice.days_overdue,
            url: invoice_path(invoice),
            pdf_url: invoice_path(invoice, format: :pdf)
          }
        }
      }
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
    format.html { render 'show_html' }  # Use new HTML template with actions
    format.pdf do
      begin
        render pdf: "invoice_#{@invoice.id}",
               template: 'invoices/show',  # Keep existing template for PDF
               layout: false,
               page_size: 'A4',
               margin: { top: 5, bottom: 5, left: 5, right: 5 },
               encoding: 'UTF-8'
      rescue => e
        Rails.logger.error "PDF generation failed: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        
        # Fallback to HTML with print-friendly styling
        flash[:alert] = "PDF generation temporarily unavailable. Showing print-friendly version."
        render template: 'invoices/show_print', layout: false, content_type: 'text/html'
      end
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
    delivery_person_id = params[:delivery_person_id]
    customer_ids = params[:customer_ids]
    
    begin
      # Determine which customers to process
      if customer_ids.present? && !customer_ids.include?('all')
        # Specific customers selected
        selected_customer_ids = customer_ids.reject { |id| id == 'all' }
        results = Invoice.generate_monthly_invoices_for_selected_customers(selected_customer_ids, month, year)
      elsif delivery_person_id.present? && delivery_person_id != 'all'
        # Specific delivery person selected
        results = Invoice.generate_monthly_invoices_for_delivery_person(delivery_person_id, month, year)
      else
        # All customers (default behavior)
        results = Invoice.generate_monthly_invoices_for_all_customers(month, year)
      end
      
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
  
  # AJAX action for search suggestions
  def search_suggestions
    query = params[:q].to_s.strip
    
    if query.present? && query.length >= 1
      # Get customers matching name or phone/alt_phone starting with/containing digits
      # Prioritize starts-with for names, allow contains for numbers
      customers = Customer.where(
                    "name ILIKE :name_q OR phone_number ILIKE :num_q OR alt_phone_number ILIKE :num_q",
                    name_q: "#{query}%",
                    num_q: "%#{query}%"
                  )
                  .limit(10)
                  .order(:name)
      
      # Get invoices matching the query
      invoices = Invoice.includes(:customer)
                       .search_by_number_or_customer(query)
                       .limit(5)
                       .order(created_at: :desc)
      
      suggestions = []
      
      customers.each do |customer|
        suggestions << {
          type: 'customer',
          label: customer.name,
          value: customer.name,
          phone: customer.phone_number.presence || customer.alt_phone_number,
          id: customer.id
        }
      end
      
      invoices.each do |invoice|
        suggestions << {
          type: 'invoice',
          label: "#{invoice.formatted_number} - #{invoice.customer.name}",
          value: invoice.formatted_number,
          customer_name: invoice.customer.name,
          amount: invoice.total_amount,
          id: invoice.id
        }
      end
      
      render json: { suggestions: suggestions }
    else
      render json: { suggestions: [] }
    end
  end
  
  def mark_as_paid
    @invoice = Invoice.find(params[:id])
    @invoice.update(status: 'paid', paid_at: Time.current)
    redirect_to invoices_path, notice: 'Invoice marked as paid.'
  end
  
  def convert_to_completed
    @invoice.update(status: 'paid', paid_at: Time.current)
    redirect_to invoices_path, notice: 'Invoice converted to completed successfully.'
  end
  
  # WhatsApp sharing action
  def share_whatsapp
    phone_number = params[:phone_number]
    
    # Validate phone number
    if phone_number.blank?
      render json: { error: 'Phone number is required' }, status: 400
      return
    end
    
    # Sanitize phone number - remove non-digits
    sanitized_phone = phone_number.gsub(/\D/, '')
    
    # Validate phone format (10-15 digits)
    unless sanitized_phone.match?(/^\d{10,15}$/)
      render json: { error: 'Invalid phone number format' }, status: 400
      return
    end
    
    # Ensure share token exists
    @invoice.generate_share_token if @invoice.share_token.blank?
    @invoice.save! if @invoice.changed?
    
    # Generate public URL with explicit host (without port for WhatsApp)
    host = request.host || Rails.application.config.action_controller.default_url_options[:host] || 'gnu-modern-totally.ngrok-free.app'
    public_url = @invoice.public_url(host: host).gsub(':3000', '')
    
    # Build WhatsApp message
    message = build_whatsapp_message(@invoice, public_url)
    
    # Create WhatsApp URL - using web.whatsapp.com for direct WhatsApp Web access
    whatsapp_url = "https://web.whatsapp.com/send?phone=#{sanitized_phone}&text=#{CGI.escape(message)}"
    
    # Mark invoice as shared
    @invoice.mark_as_shared!
    
    render json: { 
      success: true, 
      whatsapp_url: whatsapp_url,
      message: 'WhatsApp link generated successfully'
    }
  rescue => e
    Rails.logger.error "WhatsApp sharing error: #{e.message}"
    render json: { error: 'Failed to generate WhatsApp link' }, status: 500
  end
  
  # Public invoice view (no authentication required)
  def public_view
    @invoice = Invoice.find_by(share_token: params[:token])
    
    if @invoice.nil?
      render file: "#{Rails.root}/public/404.html", layout: false, status: 404
      return
    end
    
    # Mark as shared if first view
    @invoice.mark_as_shared! if @invoice.shared_at.nil?
    
    @invoice_items = @invoice.invoice_items.includes(:product)
    @customer = @invoice.customer
    
    render layout: 'public'
  end
  
  # Public PDF download (no authentication required)
  def public_download_pdf
    @invoice = Invoice.find_by(share_token: params[:token])
    
    if @invoice.nil?
      Rails.logger.warn "Invoice not found for token: #{params[:token]}"
      render file: "#{Rails.root}/public/404.html", layout: false, status: 404
      return
    end
    
    Rails.logger.info "Generating PDF for invoice #{@invoice.id} with token #{params[:token]}"
    
    @invoice_items = @invoice.invoice_items.includes(:product)
    @customer = @invoice.customer
    
    respond_to do |format|
      format.pdf do
        generate_pdf_response
      end
      
      # Handle default format (when no format is specified in URL)
      format.html do
        generate_pdf_response
      end
      
      # Handle any other format by defaulting to PDF
      format.any do
        generate_pdf_response
      end
    end
  end
  
  private

  def set_invoice
    @invoice = Invoice.find(params[:id])
  end

  def invoice_params
    params.require(:invoice).permit(:customer_id, :status, :invoice_date, :due_date, :invoice_number, :notes)
  end

  def set_customers
    @customers = Customer.order(:name)
  end

  def build_whatsapp_message(invoice, public_url)
    "Hello #{invoice.customer.name}, your invoice #{invoice.formatted_number} for ₹#{invoice.total_amount} is ready. View/download: #{public_url}"
  end

  def generate_pdf_response
    render pdf: "invoice_#{@invoice.id}",
           template: 'invoices/show',
           layout: false,
           page_size: 'A4',
           margin: { top: 5, bottom: 5, left: 5, right: 5 },
           encoding: 'UTF-8'
  end
end