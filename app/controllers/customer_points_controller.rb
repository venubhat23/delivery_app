class CustomerPointsController < ApplicationController
  def index
    # Get all customers and calculate points on-the-fly based on delivery assignments
    all_customers = Customer.includes(:delivery_assignments).order(:name)

    customers_with_calculated_points = all_customers.map do |customer|
      # Calculate total amount from completed delivery assignments
      total_amount = customer.delivery_assignments
                            .where(status: 'completed')
                            .sum(:final_amount_after_discount) || 0

      # Calculate points: 10 points for every ₹1000
      calculated_points = (total_amount / 1000.0 * 10).floor

      # Add dynamic method to customer object
      customer.define_singleton_method(:total_points) { calculated_points }
      customer.define_singleton_method(:total_delivery_amount) { total_amount }

      customer
    end

    # Split customers into those with points and those without
    @customers_with_points = customers_with_calculated_points
                            .select { |c| c.total_points > 0 }
                            .sort_by(&:total_points)
                            .reverse

    @customers_without_points = customers_with_calculated_points
                               .select { |c| c.total_points == 0 }
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
