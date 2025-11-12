# Service to send app launch event notifications to all customers
class AppLaunchNotificationService
  def self.send_to_all_customers
    begin
      Rails.logger.info "Starting app launch event notifications to all customers"

      # Check if Twilio environment variables are present and enabled
      if true
        Rails.logger.warn "Twilio environment variables not configured. Notifications disabled."
        return {
          success: false,
          message: "WhatsApp notifications are disabled. Twilio credentials not configured.",
          total_customers: 0,
          success_count: 0,
          failure_count: 0
        }
      end

      # Get all customers with phone numbers
      customers = Customer.where.not(phone_number: [nil, ''])
      total_customers = customers.count

      success_count = 0
      failure_count = 0
      # Twilio configuration (direct implementation)
      account_sid = ENV['TWILIO_ACCOUNT_SID']
      auth_token = ENV['TWILIO_AUTH_TOKEN']
      from_number = 'whatsapp:+917619444966'
      content_sid = 'HXeebae3eef939ddaa2754410ba21f0209' # Tomorrow's event template

      # Initialize Twilio client
      require 'twilio-ruby'
      client = Twilio::REST::Client.new(account_sid, auth_token)

      customers.in_batches(of: 10).each_with_index do |batch, batch_index|
        Rails.logger.info "Processing batch #{batch_index + 1} of #{(total_customers / 10.0).ceil}"

        batch.each do |customer|
          begin
            # Format phone number
            phone_number = format_phone_number(customer.phone_number)

            # Send the tomorrow's event template message
            message = client.messages.create(
              content_sid: content_sid,
              from: from_number,
              to: "whatsapp:#{phone_number}"
            )
            success_count += 1
            Rails.logger.info "Tomorrow's event message sent to #{customer.name} (#{customer.phone_number}) - SID: #{message.sid}"

          rescue Twilio::REST::RestError => e
            failure_count += 1
            Rails.logger.error "Twilio error sending to #{customer.name}: #{e.message}"
          rescue => e
            failure_count += 1
            Rails.logger.error "Error sending event message to #{customer.name}: #{e.message}"
          end
        end

        # 10 second gap between batches (except for the last batch)
        unless batch_index == (total_customers / 10.0).ceil - 1
          Rails.logger.info "Waiting 10 seconds before next batch..."
          sleep(10)
        end
      end

      Rails.logger.info "Tomorrow's event notifications completed. Success: #{success_count}, Failed: #{failure_count}"

      {
        success: true,
        total_customers: total_customers,
        success_count: success_count,
        failure_count: failure_count,
        message: "Tomorrow's event invitations sent successfully!"
      }

    rescue => e
      Rails.logger.error "Error in send_to_all_customers: #{e.message}"
      {
        success: false,
        error: e.message,
        message: "Failed to send event invitations"
      }
    end
  end

  private

  def self.format_phone_number(phone)
    # Clean phone number and add country code
    cleaned = phone.gsub(/\D/, '')

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
end