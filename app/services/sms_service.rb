class SmsService
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
  end

  # Send SMS to owner when mobile order/subscription is placed
  def send_owner_notification(type, customer_name, items_count = nil, subscription_period = nil)
    admin_settings = AdminSetting.current
    return false unless admin_settings.owner_mobile.present?

    message = build_notification_message(type, customer_name, items_count, subscription_period)
    send_sms(admin_settings.owner_mobile, message)
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

      Rails.logger.info "SMS sent successfully to #{formatted_phone}. SID: #{message_response.sid}"
      true
    rescue => e
      Rails.logger.error "Failed to send SMS to #{phone}: #{e.message}"
      false
    end
  end

  def build_notification_message(type, customer_name, items_count, subscription_period)
    case type
    when :order
      "🛒 New Order Alert!\nCustomer: #{customer_name}\nItems: #{items_count}\nSource: Mobile App\nPlease check your dashboard."
    when :subscription
      "📅 New Subscription Alert!\nCustomer: #{customer_name}\nPeriod: #{subscription_period}\nSource: Mobile App\nPlease check your dashboard."
    else
      "📱 New booking from #{customer_name} via mobile app. Check dashboard for details."
    end
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