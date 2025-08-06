#!/usr/bin/env ruby

# Sample data setup script for Milk Supply Analytics
# This script creates sample procurement schedules and assignments for testing

require 'date'

# Sample data for testing
puts "Setting up sample data for Milk Supply Analytics..."

# Assuming user ID 1 exists, create sample data
user_id = 1
start_date = Date.current - 30.days
end_date = Date.current + 7.days

# Sample vendors
vendors = [
  { name: "Sharma Dairy", buying_price: 45.0, selling_price: 50.0 },
  { name: "Kumar Milk Farm", buying_price: 42.0, selling_price: 48.0 },
  { name: "Patel Dairy Co.", buying_price: 44.0, selling_price: 49.0 },
  { name: "Singh Milk Supply", buying_price: 43.0, selling_price: 47.0 }
]

# Create procurement schedule
schedule_sql = <<-SQL
INSERT INTO procurement_schedules (user_id, name, start_date, end_date, frequency, status, created_at, updated_at)
VALUES (#{user_id}, 'Monthly Milk Procurement - #{Date.current.strftime('%B %Y')}', 
        '#{start_date}', '#{end_date}', 'daily', 'active', NOW(), NOW())
ON CONFLICT DO NOTHING;
SQL

# Create sample assignments
assignments_sql = []
(start_date..Date.current).each do |date|
  vendors.each_with_index do |vendor, index|
    # Vary the quantities to make it realistic
    base_quantity = 50 + (index * 10) + rand(20)
    planned_quantity = base_quantity + rand(10)
    
    # For past dates, create some actual quantities
    if date < Date.current
      # 80% chance of completion for past dates
      if rand < 0.8
        actual_quantity = planned_quantity + rand(-5..5)
        actual_quantity = [actual_quantity, 0].max  # Ensure non-negative
        status = 'completed'
      else
        actual_quantity = 'NULL'
        status = 'pending'
      end
    else
      actual_quantity = 'NULL'
      status = 'pending'
    end
    
    assignments_sql << <<-SQL
      INSERT INTO procurement_assignments 
      (procurement_schedule_id, user_id, vendor_name, date, planned_quantity, actual_quantity, 
       buying_price, selling_price, unit, status, created_at, updated_at)
      SELECT s.id, #{user_id}, '#{vendor[:name]}', '#{date}', #{planned_quantity}, #{actual_quantity},
             #{vendor[:buying_price]}, #{vendor[:selling_price]}, 'liters', '#{status}', NOW(), NOW()
      FROM procurement_schedules s 
      WHERE s.user_id = #{user_id} AND s.name LIKE 'Monthly Milk Procurement%'
      ON CONFLICT (procurement_schedule_id, vendor_name, date) DO NOTHING;
SQL
  end
end

# Output SQL commands
puts "\n-- SQL Commands to create sample data:"
puts schedule_sql
puts "\n-- Assignment data:"
assignments_sql.each { |sql| puts sql }

puts "\n-- Summary:"
puts "This will create:"
puts "- 1 procurement schedule"
puts "- #{vendors.size} vendors"
puts "- Approximately #{((start_date..Date.current).count * vendors.size)} assignments"
puts "- Mix of completed and pending assignments"

puts "\nTo execute these commands:"
puts "1. Connect to your PostgreSQL database"
puts "2. Run the SQL commands above"
puts "3. Refresh your milk analytics pages to see the data"