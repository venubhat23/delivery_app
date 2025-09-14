# app/services/wanotifier_service.rb
require 'net/http'
require 'uri'
require 'json'

class WanotifierService
  def initialize
    @config = load_config
    @api_key = @config['api_key']
    @base_url = @config['base_url']
  end
  
  private
  
  # Load configuration from YAML file
  def load_config
    config_file = Rails.root.join('config', 'wanotifier.yml')
    
    if File.exist?(config_file)
      YAML.load_file(config_file)[Rails.env] || {}
    else
      {
        'api_key' => ENV['WANOTIFIER_API_KEY'] || 'your_api_key_here',
        'base_url' => 'https://app.wanotifier.com/api'
      }
    end
  rescue => e
    Rails.logger.error "Error loading WANotifier config: #{e.message}"
    {
      'api_key' => ENV['WANOTIFIER_API_KEY'] || 'your_api_key_here',
      'base_url' => 'https://app.wanotifier.com/api'
    }
  end
  
  public
  
  # Send a WhatsApp message with optional PDF attachment
  def send_message(phone_number, message, pdf_url = nil)
    return false unless valid_config?
    return false unless valid_phone_number?(phone_number)
    
    formatted_number = format_phone_number(phone_number)
    
    payload = {
      api_key: @api_key,
      phone: formatted_number,
      message: message
    }
    
    # Add PDF attachment if provided
    payload[:media_url] = pdf_url if pdf_url.present?
    
    begin
      response = make_api_request('/send-message', payload)
      
      if response['success']
        Rails.logger.info "WhatsApp message sent successfully to #{formatted_number}"
        true
      else
        Rails.logger.error "WhatsApp message failed: #{response['message'] || 'Unknown error'}"
        false
      end
    rescue => e
      Rails.logger.error "WANotifier API error: #{e.message}"
      false
    end
  end
  
  # Send invoice notification via WhatsApp
  def send_invoice_notification(invoice)
    return false unless invoice&.customer&.phone_number.present?
    return false unless valid_config?
    
    begin
      # Generate invoice message
      message = build_invoice_message(invoice)
      
      # Ensure invoice has a share token for public access
      invoice.generate_share_token if invoice.share_token.blank?
      invoice.save! if invoice.changed?
      
      # Get public URLs
      host = Rails.application.config.action_controller.default_url_options[:host] || 'atmanirbharfarmbangalore.com'
      public_url = invoice.public_url(host: host).gsub(':3000', '')
      pdf_url = "#{public_url}.pdf"
      
      # Try to send with PDF first, fallback to link only if PDF fails
      success = send_message(invoice.customer.phone_number, message, pdf_url)
      
      if success
        # Mark invoice as shared
        invoice.mark_as_shared!
        Rails.logger.info "Invoice #{invoice.formatted_number} sent with PDF attachment via WhatsApp to #{invoice.customer.name}"
      else
        # Fallback: send message with link only (no PDF attachment)
        message_with_link = "#{message}\n\n📥 *View & Download:*\n#{public_url}"
        success = send_message(invoice.customer.phone_number, message_with_link)
        
        if success
          invoice.mark_as_shared!
          Rails.logger.info "Invoice #{invoice.formatted_number} sent (link only) via WhatsApp to #{invoice.customer.name}"
          Rails.logger.warn "PDF attachment failed for invoice #{invoice.formatted_number}, sent link instead"
        end
      end
      
      success
    rescue => e
      Rails.logger.error "Failed to send invoice via WANotifier to #{invoice.customer.name}: #{e.message}"
      false
    end
  end
  
  # Bulk send notifications for multiple invoices
  def send_bulk_invoice_notifications(invoices)
    results = {
      success_count: 0,
      failure_count: 0,
      errors: []
    }
    
    invoices.each_with_index do |invoice, index|
      begin
        if send_invoice_notification(invoice)
          results[:success_count] += 1
        else
          results[:failure_count] += 1
          results[:errors] << "#{invoice.customer.name}: Failed to send notification"
        end
        
        # Add delay every 5 messages to respect rate limits
        if (index + 1) % 5 == 0
          sleep(2)
          Rails.logger.info "Processed #{index + 1} notifications. Pausing to respect rate limits..."
        end
      rescue => e
        results[:failure_count] += 1
        results[:errors] << "#{invoice.customer.name}: #{e.message}"
        Rails.logger.error "Bulk send error for #{invoice.customer.name}: #{e.message}"
      end
    end
    
    results
  end
  
  # Check if the service is properly configured
  def valid_config?
    if @api_key.blank? || @api_key == 'your_api_key_here'
      Rails.logger.error "WANotifier API key not configured"
      return false
    end
    true
  end
  
  private
  
  # Format phone number for WhatsApp (Indian format)
  def format_phone_number(number)
    return nil if number.blank?
    
    # Remove any existing prefixes and non-numeric characters
    clean_number = number.to_s.gsub(/[^\d+]/, '')
    
    # Return nil if number is too short
    return nil if clean_number.length < 10
    
    # Add +91 if it doesn't start with + (assuming Indian numbers)
    unless clean_number.start_with?('+')
      # Handle Indian numbers (remove leading 0 if present)
      clean_number = clean_number.sub(/^0/, '')
      
      # Add country code for Indian numbers
      clean_number = "+91#{clean_number}"
    end
    
    # Validate final number format (should be 13 characters for Indian numbers: +91xxxxxxxxxx)
    return nil unless clean_number.match(/^\+91\d{10}$/)
    
    clean_number
  end
  
  # Validate phone number format
  def valid_phone_number?(number)
    formatted = format_phone_number(number)
    !formatted.nil?
  end
  
  # Build personalized invoice message
  def build_invoice_message(invoice)
    formatted_amount = "₹#{ActionController::Base.helpers.number_with_delimiter(invoice.total_amount, delimiter: ',')}"
    
    <<~MESSAGE.strip
      🧾 *Invoice Ready - #{invoice.formatted_number}*

      Dear #{invoice.customer.name},
      Your invoice for #{formatted_amount} from *Atmanirbhar Farm* has been prepared.

      Thank you for your business! 🙏
      🌾 *Atmanirbhar Farm*
    MESSAGE
  end
  
  # Make HTTP request to WANotifier API
  def make_api_request(endpoint, payload)
    uri = URI("#{@base_url}#{endpoint}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['Accept'] = 'application/json'
    request.body = payload.to_json
    
    response = http.request(request)
    
    case response.code
    when '200', '201'
      JSON.parse(response.body)
    else
      Rails.logger.error "WANotifier API error: #{response.code} - #{response.body}"
      { 'success' => false, 'message' => "HTTP #{response.code}: #{response.message}" }
    end
  rescue JSON::ParserError => e
    Rails.logger.error "WANotifier API response parsing error: #{e.message}"
    { 'success' => false, 'message' => 'Invalid response format' }
  rescue => e
    Rails.logger.error "WANotifier API request error: #{e.message}"
    { 'success' => false, 'message' => e.message }
  end
end