namespace :whatsapp do
  desc "Test WhatsApp connection for Render deployment"
  task :test_connection => :environment do
    puts "🔧 Testing WhatsApp connection for Render deployment..."

    result = RenderWhatsappInvoiceService.test_connection

    if result[:success]
      puts "✅ WhatsApp connection successful!"
      puts "   Account SID: #{result[:account_sid]}"
      puts "   From Number: #{result[:from_number]}"
    else
      puts "❌ WhatsApp connection failed:"
      puts "   Error: #{result[:error]}"
      puts ""
      puts "📝 Setup Instructions:"
      puts "   1. Set environment variables in Render dashboard:"
      puts "      TWILIO_ACCOUNT_SID=your_account_sid"
      puts "      TWILIO_AUTH_TOKEN=your_auth_token"
      puts "      TWILIO_PHONE_NUMBER=+1234567890"
      puts ""
      puts "   2. Or add to Rails credentials:"
      puts "      rails credentials:edit"
      puts "      Add:"
      puts "        twilio_account_sid: your_account_sid"
      puts "        twilio_auth_token: your_auth_token"
      puts "        twilio_phone_number: +1234567890"
    end
  end

  desc "Test PDF generation for Render deployment"
  task :test_pdf => :environment do
    puts "📄 Testing PDF generation for Render deployment..."

    begin
      # Find or create a test invoice
      invoice = Invoice.first

      unless invoice
        puts "❌ No invoices found in database."
        puts "   Please create an invoice first to test PDF generation."
        exit
      end

      pdf_service = RenderInvoicePdfService.new
      result = pdf_service.generate_and_store_pdf(invoice)

      if result[:success]
        puts "✅ PDF generation successful!"
        puts "   Invoice ID: #{invoice.id}"
        puts "   PDF URL: #{result[:pdf_url]}"
        puts "   Local Path: #{result[:local_path]}"
        puts "   Filename: #{result[:filename]}"
        puts ""
        puts "🌐 Your PDF will be accessible at:"
        puts "   #{result[:pdf_url]}"
      else
        puts "❌ PDF generation failed:"
        puts "   Error: #{result[:error]}"
      end

    rescue => e
      puts "❌ PDF test failed with error:"
      puts "   #{e.message}"
    end
  end

  desc "Send test WhatsApp invoice"
  task :send_test_invoice, [:invoice_id, :phone_number] => :environment do |t, args|
    invoice_id = args[:invoice_id]
    phone_number = args[:phone_number]

    unless invoice_id && phone_number
      puts "❌ Usage: rails whatsapp:send_test_invoice[invoice_id,phone_number]"
      puts "   Example: rails whatsapp:send_test_invoice[1,+919876543210]"
      exit
    end

    puts "📱 Sending test WhatsApp invoice..."
    puts "   Invoice ID: #{invoice_id}"
    puts "   Phone: #{phone_number}"

    begin
      invoice = Invoice.find(invoice_id)
      result = RenderWhatsappInvoiceService.send_invoice(invoice, phone_number: phone_number)

      if result[:success]
        puts "✅ WhatsApp message sent successfully!"
        puts "   Message SID: #{result[:message_sid]}"
        puts "   PDF URL: #{result[:pdf_url]}"
        puts "   Phone: #{result[:phone_number]}"
        puts "   #{result[:message]}"
      else
        puts "❌ WhatsApp sending failed:"
        puts "   Error: #{result[:error]}"
      end

    rescue ActiveRecord::RecordNotFound
      puts "❌ Invoice not found with ID: #{invoice_id}"
    rescue => e
      puts "❌ Test failed with error:"
      puts "   #{e.message}"
    end
  end

  desc "Setup Render environment variables"
  task :setup_render => :environment do
    puts "🚀 Render Environment Setup Guide"
    puts "=" * 50
    puts ""
    puts "1. Go to your Render dashboard"
    puts "2. Select your web service"
    puts "3. Go to Environment tab"
    puts "4. Add these environment variables:"
    puts ""
    puts "   Key: TWILIO_ACCOUNT_SID"
    puts "   Value: [Your Twilio Account SID]"
    puts ""
    puts "   Key: TWILIO_AUTH_TOKEN"
    puts "   Value: [Your Twilio Auth Token]"
    puts ""
    puts "   Key: TWILIO_PHONE_NUMBER"
    puts "   Value: [Your Twilio WhatsApp Number, e.g., +14155238886]"
    puts ""
    puts "   Key: RENDER_EXTERNAL_URL (optional)"
    puts "   Value: [Your Render app URL, e.g., https://yourapp.onrender.com]"
    puts ""
    puts "5. Redeploy your service"
    puts ""
    puts "📱 Get Twilio WhatsApp credentials:"
    puts "   1. Sign up at https://www.twilio.com/"
    puts "   2. Get your Account SID and Auth Token from Console"
    puts "   3. Enable WhatsApp Sandbox or get approved number"
    puts ""
    puts "✅ After setup, test with:"
    puts "   rails whatsapp:test_connection"
    puts "   rails whatsapp:test_pdf"
    puts "   rails whatsapp:send_test_invoice[1,+919876543210]"
  end

  desc "Clean up old PDF files"
  task :cleanup_pdfs => :environment do
    puts "🧹 Cleaning up old PDF files..."

    begin
      pdf_service = RenderInvoicePdfService.new
      pdf_service.cleanup_old_pdfs(7) # Clean files older than 7 days
      puts "✅ PDF cleanup completed!"
    rescue => e
      puts "❌ PDF cleanup failed:"
      puts "   #{e.message}"
    end
  end

  desc "Check PDF directory status"
  task :check_pdf_dir => :environment do
    puts "📁 Checking PDF directory status..."

    pdf_dir = Rails.root.join('public', 'invoices', 'pdf')

    if File.directory?(pdf_dir)
      pdf_files = Dir.glob(File.join(pdf_dir, '*.pdf'))
      puts "✅ PDF directory exists: #{pdf_dir}"
      puts "   PDF files count: #{pdf_files.count}"

      if pdf_files.any?
        puts "   Recent files:"
        pdf_files.last(5).each do |file|
          puts "     #{File.basename(file)} (#{File.mtime(file).strftime('%Y-%m-%d %H:%M')})"
        end
      end
    else
      puts "❌ PDF directory does not exist: #{pdf_dir}"
      puts "   Creating directory..."
      FileUtils.mkdir_p(pdf_dir)
      puts "✅ Directory created!"
    end
  end

  desc "Show current configuration"
  task :show_config => :environment do
    puts "⚙️  Current WhatsApp + PDF Configuration"
    puts "=" * 50

    # Check Twilio config
    puts "📱 Twilio Configuration:"
    puts "   Account SID: #{ENV['TWILIO_ACCOUNT_SID'] ? '✅ Set' : '❌ Missing'}"
    puts "   Auth Token: #{ENV['TWILIO_AUTH_TOKEN'] ? '✅ Set' : '❌ Missing'}"
    puts "   Phone Number: #{ENV['TWILIO_PHONE_NUMBER'] || '❌ Missing'}"
    puts ""

    # Check Render config
    puts "🌐 Render Configuration:"
    base_url = Rails.application.credentials.render_app_url ||
               ENV['RENDER_EXTERNAL_URL'] ||
               "https://#{ENV['RENDER_SERVICE_NAME']}.onrender.com"
    puts "   Base URL: #{base_url}"
    puts "   Service Name: #{ENV['RENDER_SERVICE_NAME'] || '❌ Missing'}"
    puts ""

    # Check PDF directory
    pdf_dir = Rails.root.join('public', 'invoices', 'pdf')
    puts "📁 PDF Storage:"
    puts "   Directory: #{File.directory?(pdf_dir) ? '✅ Exists' : '❌ Missing'}"
    puts "   Path: #{pdf_dir}"
    puts ""

    # Check database
    puts "💾 Database:"
    puts "   Invoices count: #{Invoice.count}"
    puts "   Customers count: #{Customer.count}"
  end
end