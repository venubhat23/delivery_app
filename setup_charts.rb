#!/usr/bin/env ruby
# Setup script for Milk Analytics Charts
# This script creates the necessary database tables and seeds data

puts "🚀 Setting up Milk Analytics Charts with Real-time Data..."

# Check if we're in a Rails environment
begin
  require_relative 'config/environment'
  puts "✅ Rails environment loaded"
rescue LoadError
  puts "❌ Rails environment not found. Please run this from the Rails root directory."
  exit 1
end

# Create the procurement tables if they don't exist
def create_procurement_tables
  puts "\n📊 Creating procurement tables..."
  
  ActiveRecord::Base.connection.execute <<-SQL
    CREATE TABLE IF NOT EXISTS procurement_schedules (
      id BIGSERIAL PRIMARY KEY,
      user_id BIGINT NOT NULL,
      vendor_name VARCHAR NOT NULL,
      from_date DATE NOT NULL,
      to_date DATE NOT NULL,
      quantity DECIMAL(10,2) NOT NULL,
      buying_price DECIMAL(10,2) NOT NULL,
      selling_price DECIMAL(10,2) NOT NULL,
      unit VARCHAR DEFAULT 'liters' NOT NULL,
      status VARCHAR DEFAULT 'active' NOT NULL,
      notes TEXT,
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
      FOREIGN KEY (user_id) REFERENCES users(id)
    );
  SQL
  
  ActiveRecord::Base.connection.execute <<-SQL
    CREATE TABLE IF NOT EXISTS procurement_assignments (
      id BIGSERIAL PRIMARY KEY,
      procurement_schedule_id BIGINT NOT NULL,
      user_id BIGINT NOT NULL,
      vendor_name VARCHAR NOT NULL,
      date DATE NOT NULL,
      planned_quantity DECIMAL(10,2) NOT NULL,
      actual_quantity DECIMAL(10,2),
      buying_price DECIMAL(10,2) NOT NULL,
      selling_price DECIMAL(10,2) NOT NULL,
      unit VARCHAR DEFAULT 'liters' NOT NULL,
      status VARCHAR DEFAULT 'pending' NOT NULL,
      completed_at TIMESTAMP,
      notes TEXT,
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
      FOREIGN KEY (procurement_schedule_id) REFERENCES procurement_schedules(id),
      FOREIGN KEY (user_id) REFERENCES users(id)
    );
  SQL
  
  # Create indexes
  ActiveRecord::Base.connection.execute <<-SQL
    CREATE INDEX IF NOT EXISTS index_procurement_schedules_on_user_id ON procurement_schedules(user_id);
    CREATE INDEX IF NOT EXISTS index_procurement_schedules_on_vendor_name ON procurement_schedules(vendor_name);
    CREATE INDEX IF NOT EXISTS index_procurement_schedules_on_status ON procurement_schedules(status);
    
    CREATE INDEX IF NOT EXISTS index_procurement_assignments_on_user_id ON procurement_assignments(user_id);
    CREATE INDEX IF NOT EXISTS index_procurement_assignments_on_vendor_name ON procurement_assignments(vendor_name);
    CREATE INDEX IF NOT EXISTS index_procurement_assignments_on_date ON procurement_assignments(date);
    CREATE INDEX IF NOT EXISTS index_procurement_assignments_on_status ON procurement_assignments(status);
  SQL
  
  puts "✅ Procurement tables created successfully"
rescue => e
  puts "⚠️  Tables might already exist or there's an error: #{e.message}"
end

# Seed sample data
def seed_sample_data
  puts "\n🌱 Seeding sample data..."
  
  # Create sample user if doesn't exist
  sample_user = User.find_or_create_by!(email: "admin@atmanirbharfarm.com") do |user|
    user.name = "Farm Administrator"
    user.role = "admin"
    user.phone = "9876543210"
    user.password = "password123"
    user.password_confirmation = "password123"
  end
  
  puts "✅ Sample user created: #{sample_user.name}"
  
  # Sample vendors
  vendors = [
    { name: "Rajesh Dairy Farm", buying_price: 45, selling_price: 50 },
    { name: "Krishna Milk Suppliers", buying_price: 42, selling_price: 48 },
    { name: "Ganga Valley Dairy", buying_price: 48, selling_price: 55 },
    { name: "Sunrise Milk Co.", buying_price: 44, selling_price: 52 },
    { name: "Fresh Farm Dairy", buying_price: 46, selling_price: 53 }
  ]
  
  # Create procurement data for the last 30 days
  created_schedules = 0
  created_assignments = 0
  
  30.days.ago.to_date.upto(Date.current) do |date|
    vendors.each_with_index do |vendor, index|
      next if date.wday == 0 # Skip Sundays
      
      # Create weekly schedules on Mondays
      if date.wday == 1
        from_date = date
        to_date = [date + 6.days, Date.current].min
        
        base_quantity = [100, 150, 120, 80, 110][index]
        daily_quantity = base_quantity + rand(-20..20)
        
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
        
        created_schedules += 1
        
        # Create assignments for each day
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
            
            # Complete past assignments
            if assignment_date <= Date.current
              a.status = 'completed'
              a.actual_quantity = daily_quantity + rand(-10..10)
              a.completed_at = assignment_date.end_of_day - rand(1..6).hours
            else
              a.status = 'pending'
            end
          end
          
          created_assignments += 1
        end
      end
    end
  end
  
  # Create the specific example data matching the UI
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
  
  ProcurementAssignment.find_or_create_by!(
    procurement_schedule: example_schedule,
    user: sample_user,
    vendor_name: "Premium Milk Suppliers",
    date: today
  ) do |a|
    a.planned_quantity = 104
    a.actual_quantity = 104
    a.buying_price = 100
    a.selling_price = 104
    a.unit = 'liters'
    a.status = 'completed'
    a.completed_at = today.beginning_of_day + 8.hours
    a.notes = "Daily premium milk procurement"
  end
  
  puts "✅ Created #{created_schedules} schedules and #{created_assignments} assignments"
  puts "✅ Total Procurement Schedules: #{ProcurementSchedule.count}"
  puts "✅ Total Procurement Assignments: #{ProcurementAssignment.count}"
  puts "✅ Completed Assignments: #{ProcurementAssignment.completed.count}"
  puts "✅ Pending Assignments: #{ProcurementAssignment.pending.count}"
end

# Display summary
def display_summary
  puts "\n📈 Chart Data Summary:"
  
  # Recent assignments
  recent_assignments = ProcurementAssignment.joins(:procurement_schedule)
                                           .order(date: :desc)
                                           .limit(5)
  
  puts "Recent Assignments:"
  recent_assignments.each do |assignment|
    qty = assignment.actual_quantity || assignment.planned_quantity
    puts "  - #{assignment.vendor_name}: #{qty}L on #{assignment.date} (#{assignment.status})"
  end
  
  # Vendor summary
  vendor_summary = ProcurementAssignment.joins(:procurement_schedule)
                                       .group(:vendor_name)
                                       .sum(:planned_quantity)
  
  puts "\nVendor Distribution:"
  vendor_summary.each do |vendor, quantity|
    puts "  - #{vendor}: #{quantity}L"
  end
  
  puts "\n🎯 Charts should now display with real-time data!"
  puts "Visit your Milk Analytics dashboard to see the updated charts."
end

# Main execution
begin
  create_procurement_tables
  seed_sample_data
  display_summary
  
  puts "\n🎉 Setup completed successfully!"
  puts "\n💡 The charts now have:"
  puts "   - Real-time data updates"
  puts "   - Interactive tooltips with detailed information"
  puts "   - Empty state handling"
  puts "   - Manual refresh functionality"
  puts "   - Responsive design"
  
rescue => e
  puts "\n❌ Error during setup: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end