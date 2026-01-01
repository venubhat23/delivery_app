# Script to delete duplicate customers with no delivery assignments


duplicate_customers = Customer
  .where.not(phone_number: [nil, ''])
  .group(:phone_number)
  .having('COUNT(*) > 1')
  .pluck(:phone_number)

duplicate_customers.each do |phone|
  customers = Customer.where(phone_number: phone)

  customers.each do |customer|
    delivery_count = DeliveryAssignment.where(customer_id: customer.id).count

    if delivery_count == 0
      puts "Deleting customer [#{customer.id}, '#{customer.name}'] - No deliveries"
      customer.destroy
    else
      puts "Keeping customer [#{customer.id}, '#{customer.name}'] - #{delivery_count} deliveries"
    end
  end
end