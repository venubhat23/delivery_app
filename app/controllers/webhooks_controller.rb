# app/controllers/webhooks_controller.rb
class WebhooksController < ApplicationController
  # Skip authentication for webhook endpoints (CSRF already skipped globally)
  skip_before_action :require_login

  # No authentication or token verification - completely public endpoint

  # Twilio WhatsApp incoming message webhook - COMPLETELY PUBLIC
  def twilio_whatsapp
    begin
      # Log the incoming webhook for debugging
      Rails.logger.info "PUBLIC Twilio WhatsApp Webhook received: #{params.inspect}"

      # Extract message details from Twilio webhook
      message_body = params['Body']
      from_number = params['From'] # Format: whatsapp:+1234567890
      to_number = params['To']     # Format: whatsapp:+1234567890
      message_sid = params['MessageSid']
      account_sid = params['AccountSid']

      # Clean phone numbers (remove whatsapp: prefix)
      sender_phone = from_number&.gsub('whatsapp:', '')
      receiver_phone = to_number&.gsub('whatsapp:', '')

      # Validate required parameters
      if message_body.blank? || sender_phone.blank?
        Rails.logger.error "Invalid webhook data: missing message body or sender phone"
        render json: { status: 'error', message: 'Invalid webhook data' }, status: 400
        return
      end

      # Forward message to specified number using TwilioWhatsappService
      forward_number = '+9199728 08044'

      # Create formatted message with sender info
      forwarded_message = build_forwarded_message(message_body, sender_phone, receiver_phone)

      # Send message using existing TwilioWhatsappService
      whatsapp_service = TwilioWhatsappService.new
      success = whatsapp_service.send_custom_message(forward_number, forwarded_message)

      if success
        Rails.logger.info "Successfully forwarded WhatsApp message from #{sender_phone} to #{forward_number}"

        # Log the message forwarding for record keeping
        log_message_forward(message_body, sender_phone, forward_number, message_sid)

        render json: { status: 'success', message: 'Message forwarded successfully' }, status: 200
      else
        Rails.logger.error "Failed to forward WhatsApp message from #{sender_phone}"
        render json: { status: 'error', message: 'Failed to forward message' }, status: 500
      end

    rescue => e
      Rails.logger.error "Twilio WhatsApp webhook error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { status: 'error', message: 'Internal server error' }, status: 500
    end
  end

  private

def build_forwarded_message(original_message, sender_phone, _receiver_phone)
  profile_name = params['ProfileName'] || 'Unknown Contact'
  "Message from #{profile_name} (#{sender_phone}): #{original_message}"
end

  def log_message_forward(original_message, sender_phone, forward_number, message_sid)
    begin
      # You can create a model to store these logs if needed
      # For now, just log to Rails logger
      Rails.logger.info "MESSAGE FORWARD LOG:"
      Rails.logger.info "- Original Message: #{original_message}"
      Rails.logger.info "- Sender: #{sender_phone}"
      Rails.logger.info "- Forwarded to: #{forward_number}"
      Rails.logger.info "- Twilio SID: #{message_sid}"
      Rails.logger.info "- Timestamp: #{Time.current}"

      # Optional: Store in database if you want to keep records
      # MessageForwardLog.create!(
      #   original_message: original_message,
      #   sender_phone: sender_phone,
      #   forward_number: forward_number,
      #   twilio_message_sid: message_sid,
      #   forwarded_at: Time.current
      # )
    rescue => e
      Rails.logger.error "Failed to log message forward: #{e.message}"
    end
  end

  # Webhook for Twilio delivery status updates - COMPLETELY PUBLIC
  def twilio_status
    begin
      Rails.logger.info "PUBLIC Twilio Status Webhook received: #{params.inspect}"

      message_sid = params['MessageSid']
      message_status = params['MessageStatus']

      Rails.logger.info "Message #{message_sid} status: #{message_status}"

      render json: { status: 'success' }, status: 200
    rescue => e
      Rails.logger.error "Twilio Status webhook error: #{e.message}"
      render json: { status: 'error' }, status: 500
    end
  end
end