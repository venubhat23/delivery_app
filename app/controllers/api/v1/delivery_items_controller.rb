module Api
  module V1
    class DeliveryItemsController < BaseController
      before_action :set_delivery_item, only: [:show, :update, :destroy]
      before_action :ensure_admin, except: [:index, :show]
      
      # GET /api/v1/delivery_assignments/:delivery_assignment_id/items
      def index
        assignment = DeliveryAssignment.find(params[:delivery_assignment_id])
        
        # Check if user can access this assignment's items
        unless can_access_assignment?(assignment)
          return render json: { error: "Unauthorized to view these delivery items" }, status: :unauthorized
        end
        
        items = assignment.delivery_items.includes(:product)
        
        render json: items, status: :ok
      end
      
      # GET /api/v1/delivery_items/:id
      def show
        assignment = @delivery_item.delivery_assignment
        
        # Check if user can access this item
        unless can_access_assignment?(assignment)
          return render json: { error: "Unauthorized to view this delivery item" }, status: :unauthorized
        end
        
        render json: @delivery_item, status: :ok
      end
      
      # POST /api/v1/delivery_assignments/:delivery_assignment_id/items
      def create
        assignment = DeliveryAssignment.find(params[:delivery_assignment_id])
        @delivery_item = assignment.delivery_items.build(delivery_item_params)
        
        if @delivery_item.save
          render json: @delivery_item, status: :created
        else
          render json: { errors: @delivery_item.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # PUT/PATCH /api/v1/delivery_items/:id
      def update
        if @delivery_item.update(delivery_item_params)
          render json: @delivery_item, status: :ok
        else
          render json: { errors: @delivery_item.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/delivery_items/:id
      def destroy
        @delivery_item.destroy
        head :no_content
      end
      
      private
      
      def set_delivery_item
        @delivery_item = DeliveryItem.find(params[:id])
      end
      
      def delivery_item_params
        params.permit(:product_id, :quantity)
      end
      
      def ensure_admin
        unless current_user.admin?
          render json: { error: "Only administrators can manage delivery items" }, status: :unauthorized
        end
      end
      
      def can_access_assignment?(assignment)
        return true if current_user.admin?
        return true if current_user.delivery_person? && assignment.delivery_person_id == current_user.id
        
        customer = Customer.find_by(user_id: current_user.id)
        return customer && assignment.customer_id == customer.id
      end
    end
  end
end