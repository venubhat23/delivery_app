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
