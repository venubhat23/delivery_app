class CustomerPointsController < ApplicationController
  def index
    # Optimized query to get all customer totals in one go
    customer_totals = DeliveryAssignment
                     .where(status: 'completed')
                     .joins(:customer)
                     .group('customers.id, customers.name, customers.phone_number, customers.email, customers.address, customers.is_active, customers.created_at')
                     .select('customers.*, SUM(delivery_assignments.final_amount_after_discount) as total_amount')
                     .order('customers.name')

    # Convert to hash for quick lookup
    totals_hash = {}
    customer_totals.each do |customer_data|
      total_amount = customer_data.total_amount.to_f || 0
      calculated_points = (total_amount / 1000.0 * 10).floor

      totals_hash[customer_data.id] = {
        customer: customer_data,
        total_amount: total_amount,
        total_points: calculated_points
      }
    end

    # Get customers without any completed deliveries
    customers_with_deliveries = totals_hash.keys
    customers_without_deliveries = Customer.where.not(id: customers_with_deliveries)
                                          .order(:name)

    # Prepare customers with points (sorted by points descending)
    @customers_with_points = totals_hash.values
                            .select { |data| data[:total_points] > 0 }
                            .sort_by { |data| -data[:total_points] }
                            .map do |data|
      customer = data[:customer]
      customer.define_singleton_method(:total_points) { data[:total_points] }
      customer.define_singleton_method(:total_delivery_amount) { data[:total_amount] }
      customer
    end

    # Prepare customers without points
    customers_with_zero_points = totals_hash.values
                                .select { |data| data[:total_points] == 0 }
                                .map do |data|
      customer = data[:customer]
      customer.define_singleton_method(:total_points) { 0 }
      customer.define_singleton_method(:total_delivery_amount) { data[:total_amount] }
      customer
    end

    # Add customers without any deliveries
    customers_without_deliveries.each do |customer|
      customer.define_singleton_method(:total_points) { 0 }
      customer.define_singleton_method(:total_delivery_amount) { 0 }
    end

    @customers_without_points = customers_with_zero_points + customers_without_deliveries.to_a
  end

  def show
    @customer = Customer.find(params[:id])

    # Get delivery assignments for points calculation
    completed_assignments = @customer.delivery_assignments
                                   .where(status: 'completed')
                                   .includes(:product)
                                   .order(completed_at: :desc)

    # Calculate total points and amount on-the-fly
    @total_amount_purchased = completed_assignments.sum(:final_amount_after_discount) || 0
    @total_points = (@total_amount_purchased / 1000.0 * 10).floor

    # Create point history from delivery assignments
    @customer_points = completed_assignments.map do |assignment|
      amount = assignment.final_amount_after_discount || 0
      points = (amount / 1000.0 * 10).floor

      # Create a virtual point object
      OpenStruct.new(
        created_at: assignment.completed_at || assignment.updated_at,
        action_type: 'delivery',
        points: points,
        description: "Delivery completed for ₹#{amount.round(2)} - #{assignment.product_name}",
        reference_type: 'DeliveryAssignment',
        reference_id: assignment.id
      )
    end.select { |point| point.points > 0 }
  end
end
