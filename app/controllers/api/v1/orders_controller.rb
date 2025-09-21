module Api
  module V1
    class OrdersController < BaseController
      
      # POST /api/v1/place_order
      def place_order
        ActiveRecord::Base.transaction do
          @customer = Customer.find(params[:customer_id])
          delivery_date = Date.parse(params[:delivery_date])
          items = params[:items]
          if params[:booking_done_by] == "customer"
            booked_by = 1
          elsif params[:booking_done_by] == "delivery_person"
            booked_by = 2
          else
            booked_by = 0
          end
          booked_by = booked_by
          
          unless items.present? && items.is_a?(Array)
            return render json: { error: "Items are required" }, status: :bad_request
          end
          
          # Create delivery schedule for this order (single day)
          delivery_schedule = DeliverySchedule.create!(
            customer: @customer,
            user_id: find_delivery_person_id(@customer),
            frequency: 'daily',
            start_date: delivery_date,
            end_date: delivery_date,
            status: 'active',
            default_quantity: items.first[:quantity] || 1,
            default_unit: items.first[:unit] || 'pieces',
            booked_by: booked_by
          )
          
          assignments_created = 0
          
          items.each do |item|
            product = Product.find(item[:product_id])
            
            # Check product availability
            unless product.in_stock?
              raise ActiveRecord::Rollback, "Product #{product.name} is out of stock"
            end
            
            # Create delivery assignment for each product
            delivery_assignment = DeliveryAssignment.create!(
              delivery_schedule: delivery_schedule,
              customer: @customer,
              user_id: delivery_schedule.user_id,
              product: product,
              scheduled_date: delivery_date,
              quantity: item[:quantity],
              unit: item[:unit],
              status: 'pending',
              booked_by: booked_by
            )
            
            assignments_created += 1
          end
          
          render json: {
            message: "Order placed successfully",
            delivery_schedule_id: delivery_schedule.id,
            assignments_created: assignments_created,
            order_date: delivery_date,
            customer_address: params[:customer_address],
            delivery_slot: params[:delivery_slot]
          }, status: :created
          
        rescue ActiveRecord::RecordNotFound => e
          render json: { error: "Record not found: #{e.message}" }, status: :not_found
        rescue ActiveRecord::RecordInvalid => e
          render json: { error: "Invalid data: #{e.message}" }, status: :unprocessable_entity
        rescue ActiveRecord::Rollback => e
          render json: { error: e.message }, status: :unprocessable_entity
        rescue StandardError => e
          render json: { error: "An error occurred: #{e.message}" }, status: :internal_server_error
        end
      end
      
      # GET /api/v1/orders?customer_id=5
      def index
        customer_id = params[:customer_id]
        
        unless customer_id.present?
          return render json: { error: "Customer ID is required" }, status: :bad_request
        end
        
        # Get single-day orders (delivery schedules where start_date == end_date)
        orders = DeliverySchedule.includes(:customer, :user, :product, :delivery_assignments)
                                .where(customer_id: customer_id)
                                .where('start_date = end_date')
                                .order(start_date: :desc)
        
        orders_data = orders.map do |order|
          {
            id: order.id,
            order_date: order.start_date,
            status: order.status,
            total_items: order.delivery_assignments.count,
            total_amount: order.delivery_assignments.sum { |assignment| assignment.total_amount },
            delivery_person: {
              id: order.user.id,
              name: order.user.name,
              phone: order.user.phone
            },
            items: order.delivery_assignments.map do |assignment|
              {
                product_id: assignment.product.id,
                product_name: assignment.product.name,
                quantity: assignment.quantity,
                unit: assignment.unit,
                unit_price: assignment.product.price,
                total_price: assignment.total_amount,
                status: assignment.status
              }
            end
          }
        end
        
        render json: orders_data, status: :ok
      end
      
      private
      
      def find_delivery_person_id(customer)
        # Simple logic to assign delivery person
        # In a real system, this would be more sophisticated (based on location, workload, etc.)
        customer.delivery_person_id || User.where(role: 'delivery_person').first&.id || current_user.id
      end
    end
  end
end