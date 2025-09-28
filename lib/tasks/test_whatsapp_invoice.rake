# lib/tasks/test_whatsapp_invoice.rake
namespace :whatsapp do
  desc "Test WhatsApp invoice sending"
  task test_invoice: :environment do
    puts "🧪 Testing WhatsApp Invoice System..."

    # Find first invoice or create a test one
    invoice = Invoice.first

    unless invoice
      puts "❌ No invoices found. Create an invoice first."
      exit
    end

    puts "📄 Testing with Invoice: #{invoice.invoice_number}"
    puts "👤 Customer: #{invoice.customer.name}"
    puts "📞 Phone: #{invoice.customer.phone_number}"

    # Test 1: PDF URL Generation
    puts "\n🔗 Testing PDF URL generation..."
    whatsapp_service = EnhancedTwilioWhatsappService.new

    begin
      pdf_url = whatsapp_service.send(:generate_invoice_pdf_url, invoice)

      if pdf_url.present?
        puts "✅ PDF URL generated successfully: #{pdf_url}"

        # Test if URL is accessible
        require 'net/http'
        uri = URI(pdf_url)

        begin
          response = Net::HTTP.get_response(uri)
          if response.code == '200'
            puts "✅ PDF URL is accessible"
          else
            puts "⚠️  PDF URL returned status: #{response.code}"
          end
        rescue => e
          puts "⚠️  Could not test PDF URL accessibility: #{e.message}"
        end
      else
        puts "❌ Failed to generate PDF URL"
      end
    rescue => e
      puts "❌ PDF URL generation error: #{e.message}"
    end

    # Test 2: WhatsApp Configuration Check
    puts "\n📱 Testing WhatsApp configuration..."

    twilio_account_sid = Rails.application.credentials.dig(:twilio, :account_sid) || ENV['TWILIO_ACCOUNT_SID']
    twilio_auth_token = Rails.application.credentials.dig(:twilio, :auth_token) || ENV['TWILIO_AUTH_TOKEN']
    twilio_phone = Rails.application.credentials.dig(:twilio, :phone_number) || ENV['TWILIO_PHONE_NUMBER']

    if twilio_account_sid.present? && twilio_auth_token.present? && twilio_phone.present?
      puts "✅ Twilio credentials configured"
    else
      puts "❌ Twilio credentials missing:"
      puts "   - Account SID: #{twilio_account_sid.present? ? '✅' : '❌'}"
      puts "   - Auth Token: #{twilio_auth_token.present? ? '✅' : '❌'}"
      puts "   - Phone Number: #{twilio_phone.present? ? '✅' : '❌'}"
    end

    # Test 3: AWS Configuration Check (if using S3)
    puts "\n☁️  Testing AWS configuration..."

    aws_access_key = Rails.application.credentials.dig(:aws, :access_key_id) || ENV['AWS_ACCESS_KEY_ID']
    aws_secret_key = Rails.application.credentials.dig(:aws, :secret_access_key) || ENV['AWS_SECRET_ACCESS_KEY']
    aws_bucket = Rails.application.credentials.dig(:aws, :s3_bucket) || ENV['AWS_S3_BUCKET']

    if aws_access_key.present? && aws_secret_key.present? && aws_bucket.present?
      puts "✅ AWS S3 credentials configured"

      # Test S3 connection
      begin
        require 'aws-sdk-s3'
        s3_client = Aws::S3::Client.new(
          region: Rails.application.credentials.dig(:aws, :region) || ENV['AWS_REGION'] || 'ap-south-1',
          access_key_id: aws_access_key,
          secret_access_key: aws_secret_key
        )

        s3_client.head_bucket(bucket: aws_bucket)
        puts "✅ S3 bucket is accessible"
      rescue => e
        puts "❌ S3 connection failed: #{e.message}"
      end
    else
      puts "⚠️  AWS S3 not configured (will use local URLs)"
    end

    # Ask if user wants to send test message
    puts "\n🤔 Want to send a test WhatsApp message? (y/n)"
    print "> "
    response = STDIN.gets.chomp.downcase

    if response == 'y' || response == 'yes'
      puts "📱 Enter phone number (with country code, e.g., +919876543210):"
      print "> "
      phone_number = STDIN.gets.chomp

      if phone_number.present?
        puts "\n📤 Sending test WhatsApp message..."

        begin
          result = whatsapp_service.send_invoice_notification(invoice, phone_number: phone_number)

          if result
            puts "✅ WhatsApp message sent successfully!"
          else
            puts "❌ Failed to send WhatsApp message"
          end
        rescue => e
          puts "❌ WhatsApp sending error: #{e.message}"
        end
      else
        puts "❌ Phone number is required"
      end
    else
      puts "✅ Test completed without sending message"
    end

    puts "\n📋 Summary:"
    puts "- Invoice: #{invoice.invoice_number}"
    puts "- PDF URL: #{pdf_url.present? ? '✅ Generated' : '❌ Failed'}"
    puts "- Twilio Config: #{twilio_account_sid.present? ? '✅ Ready' : '❌ Missing'}"
    puts "- AWS S3 Config: #{aws_access_key.present? ? '✅ Ready' : '⚠️  Using local URLs'}"

    puts "\n🎉 Test completed!"
  end

  desc "Send invoice to specific phone number"
  task :send_invoice, [:invoice_id, :phone_number] => :environment do |t, args|
    invoice_id = args[:invoice_id]
    phone_number = args[:phone_number]

    unless invoice_id && phone_number
      puts "Usage: rake whatsapp:send_invoice[invoice_id,phone_number]"
      puts "Example: rake whatsapp:send_invoice[1,+919876543210]"
      exit
    end

    invoice = Invoice.find(invoice_id)
    whatsapp_service = EnhancedTwilioWhatsappService.new

    puts "📤 Sending invoice #{invoice.invoice_number} to #{phone_number}..."

    result = whatsapp_service.send_invoice_notification(invoice, phone_number: phone_number)

    if result
      puts "✅ Invoice sent successfully!"
    else
      puts "❌ Failed to send invoice"
    end
  end
end