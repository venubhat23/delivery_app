# app/mailers/invoice_mailer.rb
class InvoiceMailer < ApplicationMailer
  default from: 'atmanirbharfarmbangalore@gmail.com'

  def payment_reminder(invoice)
    @invoice = invoice
    @customer = invoice.customer
    @days_until_due = (invoice.due_date - Date.current).to_i
    
    mail(
      to: @customer.email,
      subject: "Payment Reminder - Invoice #{@invoice.invoice_number}"
    )
  end

  def invoice_generated(invoice)
    @invoice = invoice
    @customer = invoice.customer
    
    mail(
      to: @customer.email,
      subject: "New Invoice #{@invoice.invoice_number} - Payment Due"
    )
  end

  def payment_confirmation(invoice)
    @invoice = invoice
    @customer = invoice.customer

    mail(
      to: @customer.email,
      subject: "Payment Received - Invoice #{@invoice.invoice_number}"
    )
  end

  def send_invoice_pdf(invoice, email)
    @invoice = invoice
    @customer = invoice.customer
    @invoice_items = invoice.invoice_items.includes(:product)
    @delivery_assignments = invoice.delivery_assignments.includes(:product, :user, :delivery_person).order(:completed_at, :scheduled_date)

    # Generate share token if not exists
    @invoice.generate_share_token if @invoice.share_token.blank?
    @invoice.save! if @invoice.changed?

    # Generate public URL for online viewing
    host = Rails.application.config.action_controller.default_url_options[:host] || 'atmanirbharfarmbangalore.com'
    protocol = Rails.env.production? ? 'https' : 'http'
    @public_url = @invoice.public_url(host: host, protocol: protocol)

    # Try to attach PDF file using the public PDF service
    begin
      # Use the same PDF service that works for WhatsApp
      pdf_result = PublicPdfService.generate_invoice_pdf(@invoice)

      if pdf_result[:success] && pdf_result[:file_path] && File.exist?(pdf_result[:file_path])
        # Read the generated PDF file
        pdf_content = File.read(pdf_result[:file_path])

        attachments["invoice_#{@invoice.formatted_number}.pdf"] = {
          mime_type: 'application/pdf',
          content: pdf_content
        }
        @has_pdf_attachment = true
        Rails.logger.info "PDF attached successfully to email for invoice #{@invoice.formatted_number}"
      else
        Rails.logger.warn "PDF service failed for email: #{pdf_result[:error] || 'No file path returned'}"

        # Fallback: Try simple HTML conversion
        begin
          html_content = render_to_string(
            template: 'invoices/show_html',
            layout: false
          )

          # Convert HTML to simple text-based attachment
          attachments["invoice_#{@invoice.formatted_number}.html"] = {
            mime_type: 'text/html',
            content: html_content
          }
          @has_pdf_attachment = false
          @has_html_attachment = true
          Rails.logger.info "HTML fallback attached for invoice #{@invoice.formatted_number}"
        rescue => html_error
          Rails.logger.error "HTML fallback failed: #{html_error.message}"
          @has_pdf_attachment = false
          @has_html_attachment = false
        end
      end
    rescue => e
      Rails.logger.error "PDF generation failed for email: #{e.message}"
      @has_pdf_attachment = false
      @has_html_attachment = false
    end

    mail(
      to: email,
      subject: "📧 Invoice #{@invoice.formatted_number} - #{@customer.name}"
    )
  end
end