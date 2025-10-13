require 'twilio-ruby'
require 'json'

class Twilio1TemplateService
  def initialize
    @account_sid = ENV['TWILIO_ACCOUNT_SID']
    @auth_token = ENV['TWILIO_AUTH_TOKEN']
    @content_sid = 'HX9e05da399e269e1982f8b5bcf4bee0a2'
    @from_number = 'whatsapp:+917619444966'
    @client = Twilio::REST::Client.new(@account_sid, @auth_token)
  end

  def send_custom_message(phone_number, message_body)
    phone_number = format_phone_number(phone_number)

    message = @client.messages.create(
      content_sid: @content_sid,
      to: "whatsapp:#{phone_number}",
      from: @from_number
    )

    Rails.logger.info "Custom WhatsApp template message sent successfully. SID: #{message.sid}"
    true
  rescue => e
    Rails.logger.error "Twilio WhatsApp template error: #{e.message}"
    false
  end

  private

  def format_phone_number(phone)
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