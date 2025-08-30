namespace :wanotifier do
  desc "Test WANotifier integration without sending actual messages"
  task test: :environment do
    puts "=== WANotifier Integration Test ==="
    
    # Test service initialization
    service = WanotifierService.new
    puts "✓ Service initialized successfully"
    
    # Test configuration
    if service.valid_config?
      puts "✓ Configuration loaded (API key present)"
    else
      puts "⚠ Configuration missing - please set WANOTIFIER_API_KEY"
    end
    
    # Test phone number formatting
    test_numbers = [
      "9876543210",
      "+919876543210", 
      "919876543210",
      "09876543210"
    ]
    
    puts "\n--- Phone Number Validation Tests ---"
    test_numbers.each do |number|
      formatted = service.send(:format_phone_number, number)
      valid = service.send(:valid_phone_number?, number)
      puts "#{number.ljust(15)} -> #{formatted || 'INVALID'} (#{valid ? 'VALID' : 'INVALID'})"
    end
    
    # Test with actual customer data
    puts "\n--- Customer Data Test ---"
    customers_with_phones = Customer.where.not(phone_number: [nil, ''])
                                  .limit(5)
    
    if customers_with_phones.any?
      customers_with_phones.each do |customer|
        formatted = service.send(:format_phone_number, customer.phone_number)
        valid = service.send(:valid_phone_number?, customer.phone_number)
        puts "#{customer.name.ljust(20)} #{customer.phone_number.ljust(15)} -> #{valid ? '✓' : '✗'} #{formatted}"
      end
    else
      puts "No customers with phone numbers found"
    end
    
    # Test invoice message generation
    puts "\n--- Message Generation Test ---"
    invoice = Invoice.includes(:customer).first
    if invoice
      message = service.send(:build_invoice_message, invoice)
      puts "Sample message for #{invoice.customer.name}:"
      puts "---"
      puts message
      puts "---"
      puts "Message length: #{message.length} characters"
    else
      puts "No invoices found for testing"
    end
    
    puts "\n=== Test Complete ==="
    puts "To actually send messages, ensure WANOTIFIER_API_KEY is set and use the regular invoice generation process."
  end
  
  desc "Send test WhatsApp message to specific number (use with caution)"
  task :send_test, [:phone_number] => :environment do |t, args|
    phone_number = args[:phone_number]
    
    if phone_number.blank?
      puts "Usage: rake wanotifier:send_test[+919876543210]"
      exit
    end
    
    service = WanotifierService.new
    
    unless service.valid_config?
      puts "Error: WANOTIFIER_API_KEY not configured"
      exit
    end
    
    unless service.send(:valid_phone_number?, phone_number)
      puts "Error: Invalid phone number format"
      exit
    end
    
    message = "Test message from Atma Nirbhar Farm delivery management system. Time: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
    
    puts "Sending test message to #{phone_number}..."
    
    if service.send_message(phone_number, message)
      puts "✓ Message sent successfully!"
    else
      puts "✗ Failed to send message. Check logs for details."
    end
  end
end