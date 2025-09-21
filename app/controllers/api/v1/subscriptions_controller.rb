module Api
  module V1
    class SubscriptionsController < BaseController
      
      # POST /api/v1/subscriptions
      def create
        ActiveRecord::Base.transaction do
          @customer = Customer.find(params[:customer_id])
          start_date = Date.parse(params[:start_date])
          end_date = Date.parse(params[:end_date])
          product = Product.find(params[:product_id])
          quantity = params[:quantity].to_f
          unit = params[:unit] || 'litre'
          cod = params[:cod] || false
          if params[:booking_done_by] == "customer"
            booked_by = 1
          elsif params[:booking_done_by] == "delvery_person" || params[:booking_done_by] == "delivery_person"
            booked_by = 2
          else
            booked_by = 0
          end
          booked_by = booked_by
                    
          # Validate date range
          if end_date <= start_date
            return render json: { error: "End date must be after start date" }, status: :bad_request
          end
          
          # Check if product is subscription eligible
          
          # Create delivery schedule for subscription
          delivery_schedule = DeliverySchedule.create!(
            customer: @customer,
            user_id: find_delivery_person_id(@customer),
            product: product,
            frequency: 'daily', # Default to daily for milk delivery
            start_date: start_date,
            end_date: end_date,
            status: 'active',
            default_quantity: quantity,
            default_unit: unit,
            cod: cod,
            booked_by: booked_by
          )
          
          assignments_created = 0
          current_date = start_date
          
          # Create delivery assignments for each day in the subscription period
          while current_date <= end_date
            # Skip Sundays if business requirement (can be configured)
            unless current_date.sunday? && params[:skip_sundays] == 'true'
              DeliveryAssignment.create!(
                delivery_schedule: delivery_schedule,
                customer: @customer,
                user_id: delivery_schedule.user_id,
                product: product,
                scheduled_date: current_date,
                quantity: quantity,
                unit: unit,
                status: 'pending',
                booked_by: booked_by
              )
              assignments_created += 1
            end
            current_date += 1.day
          end
          
          render json: {
            message: "Subscription created successfully",
            delivery_schedule_id: delivery_schedule.id,
            assignments_created: assignments_created,
            subscription_period: "#{start_date} to #{end_date}",
            total_days: (end_date - start_date).to_i + 1,
            delivery_days: assignments_created,
            estimated_total_amount: assignments_created * quantity * product.price,
            cod: delivery_schedule.cod
          }, status: :created
          
        rescue ActiveRecord::RecordNotFound => e
          render json: { error: "Record not found: #{e.message}" }, status: :not_found
        rescue ActiveRecord::RecordInvalid => e
          render json: { error: "Invalid data: #{e.message}" }, status: :unprocessable_entity
        rescue Date::Error
          render json: { error: "Invalid date format" }, status: :bad_request
        rescue StandardError => e
          render json: { error: "An error occurred: #{e.message}" }, status: :internal_server_error
        end
      end
      
      # GET /api/v1/subscriptions?customer_id=5
      def index
        customer_id = params[:customer_id]
        
        unless customer_id.present?
          return render json: { error: "Customer ID is required" }, status: :bad_request
        end
        
        # Get multi-day subscriptions (delivery schedules where start_date != end_date)
        subscriptions = DeliverySchedule.includes(:customer, :user, :product, :delivery_assignments)
                                       .where(customer_id: customer_id)
                                       .where('start_date != end_date OR end_date IS NULL')
                                       .order(start_date: :desc)
        
        subscriptions_data = subscriptions.map do |subscription|
          completed_deliveries = subscription.delivery_assignments.where(status: 'completed').count
          pending_deliveries = subscription.delivery_assignments.where(status: 'pending').count
          total_deliveries = subscription.delivery_assignments.count
          
          {
            id: subscription.id,
            product: {
              id: subscription.product&.id,
              name: subscription.product&.name,
              unit_type: subscription.product&.unit_type,
              price: subscription.product&.price
            },
            start_date: subscription.start_date,
            end_date: subscription.end_date,
            frequency: subscription.frequency,
            default_quantity: subscription.default_quantity,
            default_unit: subscription.default_unit,
            status: subscription.status,
            cod: subscription.cod,
            delivery_person: {
              id: subscription.user.id,
              name: subscription.user.name,
              phone: subscription.user.phone
            },
            progress: {
              total_deliveries: total_deliveries,
              completed_deliveries: completed_deliveries,
              pending_deliveries: pending_deliveries,
              completion_percentage: total_deliveries > 0 ? (completed_deliveries.to_f / total_deliveries * 100).round(2) : 0
            },
            estimated_total_amount: total_deliveries * subscription.default_quantity * (subscription.product&.price || 0),
            actual_total_amount: subscription.delivery_assignments.sum { |assignment| assignment.total_amount }
          }
        end
        
        render json: subscriptions_data, status: :ok
      end
      
      # PUT /api/v1/subscriptions/:id
      def update
        @subscription = DeliverySchedule.find(params[:id])
        
        # Only allow updating certain fields for active subscriptions
        allowed_params = subscription_update_params
        
        if @subscription.update(allowed_params)
          # Update future pending assignments if quantity or unit changed
          if allowed_params[:default_quantity].present? || allowed_params[:default_unit].present?
            update_future_assignments(@subscription)
          end
          
          render json: {
            message: "Subscription updated successfully",
            subscription: @subscription.as_json
          }, status: :ok
        else
          render json: { errors: @subscription.errors.full_messages }, status: :unprocessable_entity
        end
        
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Subscription not found" }, status: :not_found
      end
      
      # DELETE /api/v1/subscriptions/:id
      def destroy
        @subscription = DeliverySchedule.find(params[:id])
        
        # Cancel future deliveries but keep completed ones for history
        future_assignments = @subscription.delivery_assignments.where('scheduled_date > ?', Date.today)
        future_assignments.update_all(status: 'cancelled')
        
        @subscription.update!(status: 'cancelled')
        
        render json: {
          message: "Subscription cancelled successfully",
          cancelled_deliveries: future_assignments.count
        }, status: :ok
        
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Subscription not found" }, status: :not_found
      end
      
      private
      
      def find_delivery_person_id(customer)
        customer.delivery_person_id || User.where(role: 'delivery_person').first&.id || current_user.id
      end
      
      def subscription_update_params
        params.permit(:default_quantity, :default_unit, :end_date, :status, :cod)
      end
      
      def update_future_assignments(subscription)
        # Update pending assignments that are scheduled for future dates
        future_assignments = subscription.delivery_assignments
                                        .where('scheduled_date > ?', Date.today)
                                        .where(status: 'pending')
        
        future_assignments.update_all(
          quantity: subscription.default_quantity,
          unit: subscription.default_unit
        )
      end
    end
  end
end