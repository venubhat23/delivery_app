class WhatsappLaunchService
  def self.send_app_launch_messages
    # Run asynchronously in background
    AppLaunchMessageJob.perform_async
  end

  def self.send_template_message_to_all_customers
    begin
      customers = Customer.where.not(phone_number: [nil, ''])
      total_customers = customers.count

      Rails.logger.info "Starting to send app launch messages to #{total_customers} customers"

      success_count = 0
      error_count = 0

      customers.find_each(batch_size: 10) do |customer|
        begin
          result = send_twilio_template_message(customer)

          if result[:success]
            success_count += 1
            Rails.logger.info "Message sent successfully to #{customer.name} (#{customer.phone_number})"
          else
            error_count += 1
            Rails.logger.error "Failed to send message to #{customer.name}: #{result[:error]}"
          end

          # Add small delay to avoid rate limiting
          sleep(0.5)

        rescue => e
          error_count += 1
          Rails.logger.error "Exception sending message to #{customer.name}: #{e.message}"
        end
      end

      Rails.logger.info "App launch messages completed. Success: #{success_count}, Errors: #{error_count}"

      {
        success: true,
        total_customers: total_customers,
        success_count: success_count,
        error_count: error_count
      }

    rescue => e
      Rails.logger.error "Error in send_template_message_to_all_customers: #{e.message}"
      { success: false, error: e.message }
    end
  end

  private

  def self.send_twilio_template_message(customer)
    begin
      # Get Twilio credentials from environment or config
      account_sid = ENV['TWILIO_ACCOUNT_SID'] || Rails.application.credentials.twilio&.account_sid
      auth_token = ENV['TWILIO_AUTH_TOKEN'] || Rails.application.credentials.twilio&.auth_token
      whatsapp_from = ENV['TWILIO_WHATSAPP_FROM'] || 'whatsapp:+14155238886'

      unless account_sid && auth_token
        return { success: false, error: 'Twilio credentials not configured' }
      end

      # Initialize Twilio client
      client = Twilio::REST::Client.new(account_sid, auth_token)

      # Format phone number
      to_number = format_phone_number(customer.phone_number)

      # Send message using Twilio Content Template
      message = client.messages.create(
        content_sid: 'HX72485dee664afb45975418c55d61aab2', # Your template SID
        from: whatsapp_from,
        to: "whatsapp:#{to_number}"
      )

      Rails.logger.info "Twilio message sent: SID #{message.sid}, Status: #{message.status}"

      { success: true, message_sid: message.sid, status: message.status }

    rescue Twilio::REST::RestError => e
      Rails.logger.error "Twilio API Error: #{e.message}"
      { success: false, error: "Twilio Error: #{e.message}" }
    rescue => e
      Rails.logger.error "General error sending Twilio message: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def self.format_phone_number(phone)
    # Remove all non-digit characters
    cleaned = phone.to_s.gsub(/\D/, '')

    # Handle Indian phone numbers
    if cleaned.length == 10
      "+91#{cleaned}"
    elsif cleaned.length == 12 && cleaned.start_with?('91')
      "+#{cleaned}"
    elsif cleaned.length == 13 && cleaned.start_with?('+91')
      cleaned
    else
      "+91#{cleaned.last(10)}" # Take last 10 digits and add +91
    end
  end
end