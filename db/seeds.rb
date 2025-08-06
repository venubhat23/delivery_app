# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create sample categories
categories = [
  { name: "Dairy Products", description: "Milk, cheese, yogurt and other dairy items", color: "#007bff" },
  { name: "Beverages", description: "Juices, soft drinks, and other beverages", color: "#28a745" },
  { name: "Snacks", description: "Chips, crackers, and other snack foods", color: "#fd7e14" },
  { name: "Household", description: "Cleaning supplies and household items", color: "#6f42c1" },
  { name: "Personal Care", description: "Soap, shampoo, and personal hygiene products", color: "#e83e8c" },
  { name: "Fruits & Vegetables", description: "Fresh produce and organic items", color: "#20c997" }
]

categories.each do |category_attrs|
  Category.find_or_create_by!(name: category_attrs[:name]) do |category|
    category.description = category_attrs[:description]
    category.color = category_attrs[:color]
  end
end

puts "✅ Created #{Category.count} categories"

# Create default admin settings if not already present
unless AdminSetting.exists?
  AdminSetting.create!(
    business_name: "Atma Nirbhar Farm",
    address: "123 Farm Street\nVillage Center\nDistrict, State - 123456",
    mobile: "9876543210",
    email: "info@atmanirbharfarm.com",
    gstin: "29ABCDE1234F1Z5",
    pan_number: "ABCDE1234F",
    account_holder_name: "Atma Nirbhar Farm",
    bank_name: "Canara Bank",
    account_number: "3194201000718",
    ifsc_code: "CNRB0003194",
    upi_id: "atmanirbharfarm@paytm",
    terms_and_conditions: "Kindly make your monthly payment on or before the 10th of every month.\nPlease share the payment screenshot immediately after completing the transaction to confirm your payment."
  )
  puts "Created default admin settings"
end

# Create sample users if they don't exist
sample_user = User.find_or_create_by!(email: "admin@atmanirbharfarm.com") do |user|
  user.name = "Farm Administrator"
  user.role = "admin"
  user.phone = "9876543210"
  user.password = "password123"
  user.password_confirmation = "password123"
end

puts "✅ Created sample user: #{sample_user.name}"

# Create sample procurement schedules and assignments for realistic chart data
vendors = [
  { name: "Rajesh Dairy Farm", buying_price: 45, selling_price: 50 },
  { name: "Krishna Milk Suppliers", buying_price: 42, selling_price: 48 },
  { name: "Ganga Valley Dairy", buying_price: 48, selling_price: 55 },
  { name: "Sunrise Milk Co.", buying_price: 44, selling_price: 52 },
  { name: "Fresh Farm Dairy", buying_price: 46, selling_price: 53 }
]

# Create procurement schedules for the last 30 days
30.days.ago.to_date.upto(30.days.from_now.to_date) do |date|
  vendors.each_with_index do |vendor, index|
    # Create schedules for different date ranges to simulate real procurement
    next if date.wday == 0 # Skip Sundays
    
    # Vary the quantity based on day and vendor
    base_quantity = [100, 150, 120, 80, 110][index]
    daily_quantity = base_quantity + rand(-20..20)
    
    # Create procurement schedule for a week period
    if date.wday == 1 # Monday - create weekly schedules
      from_date = date
      to_date = date + 6.days
      
      schedule = ProcurementSchedule.find_or_create_by!(
        user: sample_user,
        vendor_name: vendor[:name],
        from_date: from_date,
        to_date: to_date
      ) do |s|
        s.quantity = daily_quantity
        s.buying_price = vendor[:buying_price] + rand(-2..2)
        s.selling_price = vendor[:selling_price] + rand(-2..2)
        s.unit = 'liters'
        s.status = 'active'
        s.notes = "Weekly milk procurement from #{vendor[:name]}"
      end
      
      # Create assignments for each day in the schedule
      (from_date..to_date).each do |assignment_date|
        next if assignment_date.wday == 0 # Skip Sundays
        
        assignment = ProcurementAssignment.find_or_create_by!(
          procurement_schedule: schedule,
          user: sample_user,
          vendor_name: vendor[:name],
          date: assignment_date
        ) do |a|
          a.planned_quantity = daily_quantity
          a.buying_price = schedule.buying_price
          a.selling_price = schedule.selling_price
          a.unit = 'liters'
          
          # Simulate completion for past dates
          if assignment_date <= Date.current
            a.status = 'completed'
            a.actual_quantity = daily_quantity + rand(-10..10)
            a.completed_at = assignment_date.end_of_day - rand(1..6).hours
          else
            a.status = 'pending'
          end
        end
      end
    end
  end
end

# Create some additional recent data for more realistic charts
# Add some completed assignments with actual quantities for the example shown in the UI
today = Date.current
example_schedule = ProcurementSchedule.find_or_create_by!(
  user: sample_user,
  vendor_name: "Premium Milk Suppliers",
  from_date: today - 3.days,
  to_date: today + 3.days
) do |s|
  s.quantity = 104
  s.buying_price = 100
  s.selling_price = 104
  s.unit = 'liters'
  s.status = 'active'
  s.notes = "Premium quality milk for processing"
end

# Create the specific assignment that matches the UI example
example_assignment = ProcurementAssignment.find_or_create_by!(
  procurement_schedule: example_schedule,
  user: sample_user,
  vendor_name: "Premium Milk Suppliers",
  date: today
) do |a|
  a.planned_quantity = 104
  a.actual_quantity = 104  # All 104 liters purchased
  a.buying_price = 100
  a.selling_price = 104
  a.unit = 'liters'
  a.status = 'completed'
  a.completed_at = today.beginning_of_day + 8.hours
  a.notes = "Daily premium milk procurement"
end

# Create some delivery assignments to simulate milk utilization
# This will show that 34L was sold and 70L remains unsold
DeliveryAssignment.find_or_create_by!(
  customer_id: 1, # Assuming customer exists or will be created
  scheduled_date: today,
  quantity: 34,
  status: 'completed'
) do |da|
  da.product_id = 1 # Assuming a milk product exists
  da.user_id = sample_user.id
  da.delivery_person_id = sample_user.id
  da.unit_price = 104
  da.total_amount = 34 * 104
end rescue nil # Ignore if customer/product doesn't exist

puts "✅ Created procurement schedules and assignments"
puts "✅ Total Procurement Schedules: #{ProcurementSchedule.count}"
puts "✅ Total Procurement Assignments: #{ProcurementAssignment.count}"
puts "✅ Completed Assignments: #{ProcurementAssignment.completed.count}"
puts "✅ Pending Assignments: #{ProcurementAssignment.pending.count}"

# Display some sample data for verification
recent_assignments = ProcurementAssignment.recent.limit(5)
puts "\n📊 Recent Procurement Assignments:"
recent_assignments.each do |assignment|
  puts "  - #{assignment.vendor_name}: #{assignment.actual_quantity || assignment.planned_quantity}L on #{assignment.date} (#{assignment.status})"
end

# Display vendor summary
vendor_summary = ProcurementAssignment.joins(:procurement_schedule)
                                     .group(:vendor_name)
                                     .sum(:planned_quantity)

puts "\n🏭 Vendor Summary (Planned Quantities):"
vendor_summary.each do |vendor, quantity|
  puts "  - #{vendor}: #{quantity}L"
end

puts "\nSeeds completed successfully!"
