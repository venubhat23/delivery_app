module Api
  module V1
    class DeliveriesController < BaseController
      before_action :ensure_delivery_person, except: [:api_not_found]
      before_action :set_delivery, only: [:complete]
      
      # POST /api/v1/deliveries/start
      def start
        # Find the nearest customer based on current coordinates
        current_lat = params[:current_lat].to_f
        current_lng = params[:current_lng].to_f
        
        # Find customers with pending deliveries for this delivery person
        pending_deliveries = DeliveryAssignment.where(user_id: current_user.id, scheduled_date: Date.today)
                                              .where("status ILIKE ANY (ARRAY[?])", ["pending", "in_progress"])
                                              .includes(:customer)
        if pending_deliveries.empty?  
          return render json: { message: "All deliveries completed for today." }, status: :ok
        end
        
        # Find the nearest customer
        nearest_delivery = find_nearest_delivery(pending_deliveries, current_lat, current_lng)
        
        if nearest_delivery
          # Mark delivery as in progress
          nearest_delivery.update(status: 'in_progress')
          render json: {
            delivery_id: nearest_delivery.id,
            delivery_quantity: nearest_delivery.quantity,
            delivery_unit: nearest_delivery.unit,
            customer: nearest_delivery.customer.as_json(except: [:user_id]),
            products: nearest_delivery.product
          }, status: :ok
        else
          render json: { message: "No deliveries found." }, status: :not_found
        end
      end
      
      # POST /api/v1/deliveries/:id/complete
      def complete
        # Check if this delivery belongs to the current delivery person
        unless @delivery.user_id == current_user.id
          return render json: { error: "Unauthorized", message: "This delivery does not belong to you" }, status: :unauthorized
        end
        
        @delivery.update(status: 'completed', completed_at: Date.today)
        
        # Get the next nearest delivery
        current_lat = params[:current_lat].to_f
        current_lng = params[:current_lng].to_f

        pending_deliveries = DeliveryAssignment.where(user_id: current_user.id, scheduled_date: Date.today)
                                              .where("status ILIKE ANY (ARRAY[?])", ["pending", "in_progress"])
                                              .includes(:customer)        

        if pending_deliveries.empty?
          render json: { 
            message: "All deliveries completed for today.",
            completed_delivery_id: @delivery.id
          }, status: :ok
        else
          nearest_delivery = find_nearest_delivery(pending_deliveries, current_lat, current_lng)
          if nearest_delivery
            nearest_delivery.update(status: 'in_progress')
            render json: {
              completed_delivery_id: @delivery.id,
              next_delivery: {
                delivery_id: nearest_delivery.id,
                customer: nearest_delivery.customer.as_json(except: [:user_id]),
                products: nearest_delivery.product
              },
              delivery_quantity: nearest_delivery.quantity,
              delivery_unit: nearest_delivery.unit,
              delivery_id: nearest_delivery.id,
              customer: nearest_delivery.customer.as_json(except: [:user_id]),
              products: nearest_delivery.product
            }, status: :ok
          else
            render json: { 
              message: "Delivery completed. No more deliveries available.",
              completed_delivery_id: @delivery.id
            }, status: :ok
          end
        end
      end

      # GET /api/v1/deliveries/today_summary
      def today_summary
        today = Date.today
        
        # Get all delivery assignments for today
        todays_assignments = DeliveryAssignment.where(
          user_id: current_user.id, 
          scheduled_date: today
        ).includes(:customer, :product)
        
        # Calculate counts by status
        total_count = todays_assignments.count
        completed_count = todays_assignments.where(status: 'completed').count
        pending_count = todays_assignments.where(status: 'pending').count
        in_progress_count = todays_assignments.where(status: 'in_progress').count
        
        # Get customer list with delivery details
        customer_list = todays_assignments.map do |assignment|
          {
            delivery_id: assignment.id,
            customer: {
              id: assignment.customer.id,
              name: assignment.customer.name,
              address: assignment.customer.address,
              latitude: assignment.customer.latitude,
              longitude: assignment.customer.longitude,
              image_url: assignment.customer.image_url
            },
            product: {
              id: assignment.product&.id,
              name: assignment.product&.name,
              quantity: assignment.quantity,
              unit: assignment.unit
            },
            status: assignment.status,
            completed_at: assignment.completed_at
          }
        end
        
        render json: {
          date: today,
          delivery_summary: {
            total_deliveries: total_count,
            completed: completed_count,
            pending: pending_count,
            in_progress: in_progress_count,
            completion_rate: total_count > 0 ? ((completed_count.to_f / total_count) * 100).round(2) : 0
          },
          customers: customer_list
        }, status: :ok
      end

      # GET /api/v1/deliveries/customers
      def customers
        if current_user.delivery_person?
          # Get all customers assigned to this delivery person
          assigned_customers = Customer.joins(:deliveries)
                                      .where(deliveries: { user_id: current_user.id })
                                      .distinct
          
          render json: assigned_customers, status: :ok
        else
          render json: { error: "Only delivery personnel can access this endpoint" }, status: :unauthorized
        end
      end
      
      def api_not_found
        render json: { 
          error: "Not found", 
          message: "The requested delivery endpoint does not exist. Use 'complete' instead of partial URLs." 
        }, status: :not_found
      end
      
      private
      
      def ensure_delivery_person
        unless current_user.delivery_person?
          render json: { error: "Only delivery personnel can perform this action" }, status: :unauthorized
        end
      end
      
      def set_delivery
        @delivery = DeliveryAssignment.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Delivery not found", message: "The specified delivery does not exist" }, status: :not_found
      end
      
      def find_nearest_delivery(deliveries, current_lat, current_lng)
        nearest = nil
        min_distance = Float::INFINITY
        
        deliveries.each do |delivery|
          customer = delivery.customer
          distance = Geocoder::Calculations.distance_between(
            [current_lat, current_lng],
            [customer.latitude, customer.longitude]
          )
          
          if distance < min_distance
            min_distance = distance
            nearest = delivery
          end
        end
        
        nearest
      end
    end
  end
end
