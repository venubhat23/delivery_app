# Complete Rails Console PDF to WhatsApp Test Script
# Run this in Rails console: rails console
# Then copy and paste the functions below

puts "=== Rails Console PDF to WhatsApp Test Guide ==="
puts "Loading required services and functions..."

# Test WATI Connection
def test_wati_connection
  puts "\n=== Testing WATI Connection ==="
  wati = WatiService.new
  result = wati.test_connection
  puts "Connection Result: #{result}"
  result[:success]
end

# Create or find test customer
def find_or_create_test_customer(phone_number = "919876543210", name = "Test Customer")
  puts "\n=== Finding/Creating Test Customer ==="
  
  # Check if Customer model has phone_number field
  if Customer.column_names.include?('phone_number')
    customer = Customer.find_or_create_by(phone_number: phone_number) do |c|
      c.name = name
      # Set other required fields based on your Customer model
      c.address = "Test Address" if Customer.column_names.include?('address')
      c.user = User.first if Customer.column_names.include?('user_id') && User.exists?
    end
  else
    # Fallback if phone_number field doesn't exist
    customer = Customer.first || Customer.create!(
      name: name,
      address: "Test Address"
    )
  end
  
  puts "Customer: #{customer.name} - ID: #{customer.id}"
  customer
end

# Generate PDF test
def test_pdf_generation(customer)
  puts "\n=== Testing PDF Generation ==="
  
  pdf_service = InvoicePdfService.new(customer)
  pdf_path = pdf_service.save_to_file
  
  puts "PDF saved to: #{pdf_path}"
  puts "File exists: #{File.exist?(pdf_path)}"
  puts "File size: #{File.size(pdf_path)} bytes" if File.exist?(pdf_path)
  
  pdf_path
end

# Test message sending
def test_message_sending(phone_number, message = "Hello! Your invoice is being prepared.")
  puts "\n=== Testing Message Sending ==="
  
  wati = WatiService.new
  result = wati.send_message(phone_number, message)
  puts "Message Result: #{result}"
  result[:success]
end

# Test document sending (requires accessible URL)
def test_document_sending(phone_number, pdf_path, caption = "Your invoice is ready!")
  puts "\n=== Testing Document Sending ==="
  
  # For testing, we'll use a dummy URL since we need a publicly accessible URL
  # In production, you would upload to cloud storage or serve via your Rails app
  pdf_filename = File.basename(pdf_path)
  pdf_url = "http://localhost:3000/temp_pdf/#{pdf_filename}"
  
  puts "PDF URL: #{pdf_url}"
  puts "Note: This requires Rails server to be running on localhost:3000"
  
  wati = WatiService.new
  result = wati.send_document(phone_number, pdf_url, caption)
  puts "Document Send Result: #{result}"
  result[:success]
end

# Complete end-to-end test function
def test_complete_flow(phone_number = "919876543210", customer_name = "Test Customer")
  puts "\n" + "="*50
  puts "=== Starting Complete PDF to WhatsApp Flow ==="
  puts "="*50
  
  begin
    # Step 1: Test WATI connection
    unless test_wati_connection
      puts "❌ WATI connection failed. Check your credentials."
      return false
    end
    puts "✅ WATI Connection: Success"
    
    # Step 2: Find or create customer
    customer = find_or_create_test_customer(phone_number, customer_name)
    puts "✅ Customer: #{customer.name}"
    
    # Step 3: Add customer to WATI
    wati = WatiService.new
    result = wati.add_contact(customer.phone_number || phone_number, customer.name)
    puts "✅ WATI Contact: #{result[:success] ? 'Added' : 'Failed (may already exist)'}"
    
    # Step 4: Generate PDF
    pdf_path = test_pdf_generation(customer)
    puts "✅ PDF Generated: #{File.basename(pdf_path)}"
    
    # Step 5: Send test message
    if test_message_sending(phone_number, "Your invoice is ready! 📄")
      puts "✅ Message Sent: Success"
    else
      puts "❌ Message Sent: Failed"
    end
    
    # Step 6: Send PDF (commented out as it requires server)
    puts "\n📝 Note: To test PDF sending, start Rails server with 'rails server'"
    puts "   Then uncomment the line below and run again:"
    puts "   # test_document_sending('#{phone_number}', '#{pdf_path}')"
    
    puts "\n" + "="*50
    puts "=== Flow Complete! ==="
    puts "="*50
    
    return {
      customer: customer,
      pdf_path: pdf_path,
      wati_service: wati
    }
    
  rescue => e
    puts "❌ Error in complete flow: #{e.message}"
    puts e.backtrace.first(5)
    false
  end
end

# Bulk test function (small batch)
def bulk_test(limit = 3)
  puts "\n=== Running Bulk Test (#{limit} customers) ==="
  
  customers = Customer.limit(limit)
  
  if customers.empty?
    puts "No customers found. Creating test customers..."
    3.times do |i|
      Customer.create!(
        name: "Test Customer #{i+1}",
        phone_number: "91987654321#{i}",
        address: "Test Address #{i+1}",
        user: User.first
      )
    end
    customers = Customer.limit(limit)
  end
  
  customers.each_with_index do |customer, index|
    puts "\nProcessing #{index + 1}/#{limit}: #{customer.name}"
    
    begin
      phone = customer.phone_number || "919876543210"
      result = test_complete_flow(phone, customer.name)
      puts "✅ Success for #{customer.name}"
    rescue => e
      puts "❌ Error for #{customer.name}: #{e.message}"
    end
    
    # Rate limiting
    sleep(3) if index < limit - 1
  end
end

# Environment check
def check_environment
  puts "\n=== Environment Check ==="
  puts "Rails version: #{Rails.version}"
  puts "Ruby version: #{RUBY_VERSION}"
  puts "Customer model exists: #{defined?(Customer) ? 'Yes' : 'No'}"
  puts "User model exists: #{defined?(User) ? 'Yes' : 'No'}"
  puts "Customer count: #{Customer.count rescue 'N/A'}"
  puts "User count: #{User.count rescue 'N/A'}"
  
  if defined?(Customer)
    puts "Customer fields: #{Customer.column_names.join(', ')}"
  end
end

# Quick test function
def quick_test
  puts "\n=== Quick Test ==="
  check_environment
  test_complete_flow
end

# Instructions
puts "\n" + "="*60
puts "AVAILABLE FUNCTIONS:"
puts "="*60
puts "• check_environment          - Check Rails environment"
puts "• test_wati_connection      - Test WATI API connection"
puts "• quick_test                - Run complete quick test"
puts "• test_complete_flow(phone, name) - Full end-to-end test"
puts "• bulk_test(limit)          - Test multiple customers"
puts "• test_pdf_generation(customer) - Test PDF generation only"
puts ""
puts "QUICK START:"
puts "1. Run: check_environment"
puts "2. Run: quick_test"
puts "3. Or run: test_complete_flow('YOUR_PHONE_NUMBER', 'Your Name')"
puts ""
puts "Example: test_complete_flow('919876543210', 'John Doe')"
puts "="*60