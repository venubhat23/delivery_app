class MobileNotificationService
  def initialize
    # Twilio configuration
    @account_sid = Rails.application.credentials.twilio_account_sid || ENV['TWILIO_ACCOUNT_SID']
    @auth_token = Rails.application.credentials.twilio_auth_token || ENV['TWILIO_AUTH_TOKEN']
    @from_number = Rails.application.credentials.twilio_from_number || ENV['TWILIO_FROM_NUMBER']

    # Initialize Twilio client if credentials are present
    @client = if @account_sid.present? && @auth_token.present?
      require 'twilio-ruby'
      Twilio::REST::Client.new(@account_sid, @auth_token)
    else
      nil
    end

    # Hardcoded notification number as requested
    @notification_number = '989988832832'
  end

  # Send notification when customer signs up from mobile app
  def send_signup_notification(customer)
    message = build_signup_message(customer)
    send_sms(@notification_number, message)
  end

  # Send notification when customer places order from mobile app
  def send_order_notification(customer, order)
    message = build_order_message(customer, order)
    send_sms(@notification_number, message)
  end

  private

  def send_sms(phone, message)
    return false unless @client.present? && @from_number.present?

    begin
      formatted_phone = format_phone_number(phone)

      message_response = @client.messages.create(
        from: @from_number,
        to: formatted_phone,
        body: message
      )

      Rails.logger.info "Mobile app SMS sent successfully to #{formatted_phone}. SID: #{message_response.sid}"
      true
    rescue => e
      Rails.logger.error "Failed to send mobile app SMS to #{phone}: #{e.message}"
      false
    end
  end

  def build_signup_message(customer)
    <<~MESSAGE
📱 NEW CUSTOMER SIGNUP - Mobile App

👤 Name: #{customer.name}
📞 Phone: #{customer.phone_number}
📍 Address: #{customer.address}
📧 Email: #{customer.email.presence || 'Not provided'}
🆔 Member ID: #{customer.member_id || 'Auto-generated'}

📅 Signed up: #{Time.current.strftime('%d %B %Y at %I:%M %p')}

Please welcome the new customer and follow up for their first order.
    MESSAGE
  end

  def build_order_message(customer, order)
    <<~MESSAGE
🛒 NEW ORDER - Mobile App

👤 Customer: #{customer.name}
📞 Phone: #{customer.phone_number}

📦 Product: #{order[:product_name]}
📊 Quantity: #{order[:quantity]} #{order[:unit]}
📅 Delivery Date: #{order[:delivery_date]}
📍 Address: #{order[:delivery_address]}

💰 Amount: ₹#{order[:amount]}

📝 Notes: #{order[:notes].presence || 'No special instructions'}

🕐 Ordered: #{Time.current.strftime('%d %B %Y at %I:%M %p')}

Please process this order and arrange delivery.
    MESSAGE
  end

  def format_phone_number(phone)
    # Remove any non-numeric characters
    clean_phone = phone.to_s.gsub(/\D/, '')

    # Add country code if not present (assuming India +91)
    if clean_phone.length == 10
      "+91#{clean_phone}"
    elsif clean_phone.length == 12 && clean_phone.start_with?('91')
      "+#{clean_phone}"
    elsif clean_phone.start_with?('+')
      clean_phone
    else
      "+91#{clean_phone}" # Default to India
    end
  end
end