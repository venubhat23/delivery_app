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

puts "Seeds completed successfully!"
