# app/services/whatsapp_service.rb
require 'twilio-ruby'

class WhatsappService
  # Configuration
  ACCOUNT_SID = 'ACa48d154788177a621c9acf8b0d99e7e5'
  AUTH_TOKEN  = '6cb8c1e23b39843e1ee104d76e5fc081'
  FROM_NUMBER = 'whatsapp:+14155238886' # Twilio Sandbox WhatsApp number
  
  def initialize
    @client = Twilio::REST::Client.new(ACCOUNT_SID, AUTH_TOKEN)
  end
  
  # Send a plain text WhatsApp message
  def send_text(to_number, message)
    formatted_number = format_phone_number(to_number)
    
    @client.messages.create(
      from: FROM_NUMBER,
      to: "whatsapp:#{formatted_number}",
      body: message
    )
  rescue Twilio::REST::RestError => e
    Rails.logger.error "WhatsApp text sending failed: #{e.message}"
    raise e
  end
  
  # Send a PDF (or other media) via WhatsApp
  def send_pdf(to_number, pdf_url, message = 'Please find the attached PDF')
    formatted_number = format_phone_number(to_number)
    
    @client.messages.create(
      from: FROM_NUMBER,
      to: "whatsapp:#{formatted_number}",
      body: message,
      media_url: [pdf_url]
    )
  rescue Twilio::REST::RestError => e
    Rails.logger.error "WhatsApp PDF sending failed: #{e.message}"
    raise e
  end
  
  # Send invoice notification with PDF
  def send_invoice_notification(invoice)
    # return false unless invoice&.customer&.phone_number.present?
    
    begin
      message = build_invoice_message(invoice)
      pdf_url = "https://conasems-ava-prod.s3.sa-east-1.amazonaws.com/aulas/ava/dummy-1641923583.pdf"
      
      send_pdf(invoice.customer.phone_number, pdf_url, message)
      
      # Log successful send
      Rails.logger.info "Invoice WhatsApp sent successfully to #{invoice.customer.name} (#{invoice.customer.phone_number})"
      true
    rescue => e
      Rails.logger.error "Failed to send invoice WhatsApp to #{invoice.customer.name}: #{e.message}"
      false
    end
  end
  
  private
  
  # Format phone number to ensure it has country code
  def format_phone_number(number)
    # Remove any existing 'whatsapp:' prefix
    clean_number = number.to_s.gsub(/^whatsapp:/, '')
    
    # Add +91 if it doesn't start with + (assuming Indian numbers)
    unless clean_number.start_with?('+')
      clean_number = "+919632850872"
    end
    
    clean_number
  end
  
  # Build personalized invoice message
  def build_invoice_message(invoice)
    month_year = invoice.invoice_date.strftime("%B %Y")
    formatted_amount = "₹#{ActionController::Base.helpers.number_with_delimiter(invoice.total_amount)}"
    due_date = invoice.due_date.strftime('%d %B %Y')
    
    <<~MESSAGE.strip
      Hello #{invoice.customer.name}! 👋

      Your #{month_year} invoice is ready! 📋

      📄 Invoice #: #{invoice.formatted_number}
      💰 Total Amount: #{formatted_amount}
      📅 Due Date: #{due_date}

      Please find your detailed invoice attached as PDF.

      Thank you for your continued business! 🙏

      For any queries, please contact us.
    MESSAGE
  end
end