# app/services/twilio_whatsapp_service.rb
require 'twilio-ruby'
require 'json'

class TwilioWhatsappService
  def initialize
    @account_sid = 'AC1c16e45dd041d5fb75f4c0b16e4b1e1e'
    @auth_token = '4f9a9be6caccd2e5bea55c892ed96e60'
    @content_sid = 'HX76519f55cd2df98449cb2a99852d796a'
    @from_number = 'whatsapp:+917338500872'
    @client = Twilio::REST::Client.new(@account_sid, @auth_token)
  end

  def send_bulk_invoice_notifications(invoices)
    success_count = 0
    failure_count = 0

    invoices.each do |invoice|
      begin
        host = Rails.application.config.action_controller.default_url_options[:host] || 'atmanirbharfarmbangalore.com'
        public_url = invoice.public_url(host: host).gsub(':3000', '')
        if send_invoice_notification(invoice, public_url: public_url)
          success_count += 1
        else
          failure_count += 1
        end
      rescue => e
        Rails.logger.error "Failed to send WhatsApp message for invoice #{invoice.id}: #{e.message}"
        failure_count += 1
      end
    end

    { success_count: success_count, failure_count: failure_count }
  end

  def send_invoice_notification(invoice, phone_number: nil, public_url: nil)
    if phone_number.nil?
      return false unless invoice.customer&.phone_number.present?
    end

    # Format phone number for WhatsApp
    phone_number = phone_number || invoice.customer.phone_number
    phone_number = format_phone_number(phone_number)
    # Calculate due date (10 days from now or use invoice due date)
    due_date = invoice.due_date.presence || (Date.current + 10.days)
      
    if public_url.present?
      public_url = public_url
    else
      public_url = generate_invoice_pdf_url(invoice)
    end
    # Prepare content variables
    content_variables = {
      '1' => invoice.customer.name,
      '2' => invoice.created_at.strftime('%B %Y'),  # Month year
      '3' => invoice.invoice_number,
      '4' => invoice.total_amount.to_s,
      '5' => due_date.strftime('%d/%m/%Y'),
      '6' => public_url
    }

    # Generate PDF URL for media attachment
    pdf_url = public_url

    message = @client.messages.create(
      content_sid: @content_sid,
      to: "whatsapp:#{phone_number}",
      from: @from_number,
      content_variables: content_variables.to_json,
      media_url: [pdf_url]
    )

    Rails.logger.info "WhatsApp message sent successfully. SID: #{message.sid}"
    true
  rescue => e
    Rails.logger.error "Twilio WhatsApp error: #{e.message}"
    false
  end

  private

  def format_phone_number(phone)
    # Remove any non-digit characters and ensure it starts with +91
    cleaned = phone.gsub(/\D/, '')

    # Add country code if not present
    if cleaned.length == 10
      "+91#{cleaned}"
    elsif cleaned.length == 12 && cleaned.start_with?('91')
      "+#{cleaned}"
    elsif cleaned.length == 13 && cleaned.start_with?('+91')
      cleaned
    else
      "+91#{cleaned}"
    end
  end

  def generate_invoice_pdf_url(invoice)
    # Generate the full URL for the invoice PDF
    # This should match your invoice PDF download route
    Rails.application.routes.url_helpers.download_pdf_invoice_url(
      invoice,
      host: Rails.application.config.action_mailer.default_url_options[:host] || 'localhost:3000'
    )
  rescue => e
    Rails.logger.error "Error generating PDF URL for invoice #{invoice.id}: #{e.message}"
    # Fallback URL using the correct route
    "#{Rails.application.config.action_mailer.default_url_options[:host] || 'http://localhost:3000'}/invoices/#{invoice.id}/download_pdf"
  end
end