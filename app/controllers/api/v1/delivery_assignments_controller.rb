module Api
  module V1
    class DeliveryAssignmentsController < BaseController
      before_action :set_assignment, only: [:show, :update]
      before_action :ensure_authorized, only: [:update]
      
      # GET /api/v1/delivery_assignments
      def index
        if current_user.admin?
          # Admins can see all assignments
          assignments = DeliveryAssignment.all.includes(:customer, :delivery_person)
        elsif current_user.delivery_person?
          # Delivery people see only their assignments for today and upcoming days
          assignments = DeliveryAssignment.where(
            delivery_person_id: current_user.id,
            scheduled_date: Date.today..
          ).includes(:customer)
        else
          # Customers see only their assignments
          customer = Customer.find_by(user_id: current_user.id)
          assignments = customer ? DeliveryAssignment.where(customer_id: customer.id).includes(:delivery_person) : []
        end
        
        render json: assignments, status: :ok
      end
      
      # GET /api/v1/delivery_assignments/:id
      def show
        render json: @assignment, status: :ok
      end
      
      # GET /api/v1/delivery_assignments/today
      def today
        if current_user.delivery_person?
          assignments = DeliveryAssignment.where(
            delivery_person_id: current_user.id,
            scheduled_date: Date.today,
            status: ['pending', 'in_progress']
          ).includes(:customer, delivery_items: :product)
          
          render json: assignments, status: :ok
        else
          render json: { error: "Only delivery personnel can access this endpoint" }, status: :unauthorized
        end
      end
      
      # POST /api/v1/delivery_assignments/:id/add_items
      def add_items
        @assignment = DeliveryAssignment.find(params[:id])
        
        unless current_user.admin?
          return render json: { error: "Only administrators can add items to deliveries" }, status: :unauthorized
        end
        
        ActiveRecord::Base.transaction do
          items_params.each do |item|
            @assignment.delivery_items.create!(
              product_id: item[:product_id],
              quantity: item[:quantity]
            )
          end
        end
        
        render json: @assignment, status: :ok
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.message }, status: :unprocessable_entity
      end
      
      # POST /api/v1/delivery_assignments/start_nearest
      def start_nearest
        unless current_user.delivery_person?
          return render json: { error: "Only delivery personnel can perform this action" }, status: :unauthorized
        end
        
        current_lat = params[:current_lat].to_f
        current_lng = params[:current_lng].to_f
        
        # Find today's pending assignments for this delivery person
        pending_assignments = DeliveryAssignment.where(
          delivery_person_id: current_user.id,
          scheduled_date: Date.today,
          status: 'pending'
        ).includes(:customer, delivery_items: :product)
        
        if pending_assignments.empty?
          return render json: { message: "All deliveries completed for today." }, status: :ok
        end
        
        # Find the nearest customer
        nearest_assignment = find_nearest_assignment(pending_assignments, current_lat, current_lng)
        
        if nearest_assignment
          # Mark assignment as in progress
          nearest_assignment.update(status: 'in_progress')
          
          render json: {
            assignment_id: nearest_assignment.id,
            customer: nearest_assignment.customer.as_json(except: [:user_id]),
            products: nearest_assignment.delivery_items.map do |item|
              {
                product_id: item.product_id,
                name: item.product.name,
                quantity: item.quantity,
                unit_type: item.product.unit_type
              }
            end
          }, status: :ok
        else
          render json: { message: "No deliveries found." }, status: :not_found
        end
      end
      
      # POST /api/v1/delivery_assignments/:id/complete
      def complete
        @assignment = DeliveryAssignment.find(params[:id])
        
        # Check if this assignment belongs to the current delivery person
        unless @assignment.delivery_person_id == current_user.id
          return render json: { error: "Unauthorized to complete this delivery" }, status: :unauthorized
        end
        
        # Check if the assignment is in progress
        unless @assignment.status == 'in_progress'
          return render json: { error: "This delivery must be in progress before it can be completed" }, status: :bad_request
        end
        
        ActiveRecord::Base.transaction do
          # Update product quantities
          @assignment.delivery_items.each do |item|
            product = item.product
            product.with_lock do
              product.available_quantity -= item.quantity
              product.save!
            end
          end
          
          # Mark assignment as completed
          @assignment.update!(
            status: 'completed',
            completed_at: Time.current,
            notes: params[:notes]
          )
        end
        
        # Get the next nearest assignment
        current_lat = params[:current_lat].to_f
        current_lng = params[:current_lng].to_f
        
        pending_assignments = DeliveryAssignment.where(
          delivery_person_id: current_user.id,
          scheduled_date: Date.today,
          status: 'pending'
        ).includes(:customer, delivery_items: :product)
        
        if pending_assignments.empty?
          render json: { message: "All deliveries completed for today." }, status: :ok
        else
          next_assignment = find_nearest_assignment(pending_assignments, current_lat, current_lng)
          next_assignment.update(status: 'in_progress')
          
          render json: {
            next_customer: next_assignment.customer.as_json(except: [:user_id]),
            products: next_assignment.delivery_items.map do |item|
              {
                product_id: item.product_id,
                name: item.product.name,
                quantity: item.quantity,
                unit_type: item.product.unit_type
              }
            end
          }, status: :ok
        end
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.message }, status: :unprocessable_entity
      end
      
      private
      
      def set_assignment
        @assignment = DeliveryAssignment.find(params[:id])
      end
      
      def ensure_authorized
        unless current_user.admin? || 
               (current_user.delivery_person? && @assignment.delivery_person_id == current_user.id) ||
               (Customer.find_by(user_id: current_user.id)&.id == @assignment.customer_id)
          render json: { error: "Unauthorized to access this delivery assignment" }, status: :unauthorized
        end
      end
      
      def items_params
        params.require(:items).map do |item|
          item.permit(:product_id, :quantity)
        end
      end
      
      def find_nearest_assignment(assignments, current_lat, current_lng)
        nearest = nil
        min_distance = Float::INFINITY
        
        assignments.each do |assignment|
          customer = assignment.customer
          distance = Geocoder::Calculations.distance_between(
            [current_lat, current_lng],
            [customer.latitude, customer.longitude]
          )
          
          if distance < min_distance
            min_distance = distance
            nearest = assignment
          end
        end
        
        nearest
      end
    end
  end
end