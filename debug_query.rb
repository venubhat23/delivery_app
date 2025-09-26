#!/usr/bin/env ruby

# Add Rails environment
require_relative 'config/environment'

# Enable query logging
ActiveRecord::Base.logger = Logger.new(STDOUT)

puts "=== Testing MilkAnalytics queries ==="

# Find a user
user = User.first
unless user
  puts "No user found"
  exit 1
end

puts "Using user: #{user.email}"

# Set up date range (same as controller)
start_date = Date.current.beginning_of_month
end_date = Date.current.end_of_month
product_id = nil

puts "Date range: #{start_date} to #{end_date}"

# Test each query that might be causing issues
begin
  puts "\n1. Testing basic procurement assignments query..."
  base_query = user.procurement_assignments.for_date_range(start_date, end_date)
  puts "Basic query count: #{base_query.count}"

  puts "\n2. Testing vendor summary query..."
  procurement_data = user.procurement_assignments.for_date_range(start_date, end_date)
  result = procurement_data.reorder('').group(:vendor_name).select(
    'vendor_name',
    'SUM(COALESCE(planned_quantity, 0)) as total_quantity',
    'SUM(COALESCE(planned_quantity, 0) * buying_price) as total_amount'
  ).to_a
  puts "Vendor summary works: #{result.size} vendors"

  puts "\n3. Testing dashboard stats query..."
  base_query = user.procurement_assignments.for_date_range(start_date, end_date)
  procurement_stats = base_query.reorder('').select(
    'COUNT(DISTINCT vendor_name) as vendor_count',
    'SUM(COALESCE(planned_quantity, 0)) as total_quantity',
    'SUM(COALESCE(planned_quantity, 0) * COALESCE(buying_price, 0)) as total_cost'
  ).first
  puts "Dashboard stats works: #{procurement_stats.vendor_count} vendors"

  puts "\n4. Testing distinct count query..."
  total_vendors = user.procurement_assignments.for_date_range(start_date, end_date).reorder('').distinct.count(:vendor_name)
  puts "Distinct count works: #{total_vendors} vendors"

  puts "\n5. Testing group_by query (the problematic all_vendors query)..."
  all_vendors = user.procurement_assignments.for_date_range(start_date, end_date).group_by(&:vendor_name)
  puts "Group by works: #{all_vendors.size} vendors"

rescue => e
  puts "ERROR: #{e.message}"
  puts "SQL: #{e.try(:sql) || 'No SQL available'}"
  puts "Backtrace:"
  puts e.backtrace[0..10]
end