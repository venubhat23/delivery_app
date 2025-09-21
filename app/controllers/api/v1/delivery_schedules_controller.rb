module Api
  module V1
    class DeliverySchedulesController < BaseController
      before_action :set_delivery_schedule, only: [:show, :update, :destroy]
      
      # GET /api/v1/delivery_schedules
      def index
        if current_user.admin?
          # Admins can see all schedules
          schedules = DeliverySchedule.all.includes(:customer, :user)
        elsif current_user.delivery_person?
          # Delivery people see only their schedules
          schedules = DeliverySchedule.where(user_id: current_user.id).includes(:customer)
        else
          # Customers see only their schedules
          customer = Customer.find_by(user_id: current_user.id)
          schedules = customer ? DeliverySchedule.where(customer_id: customer.id).includes(:delivery_person) : []
        end
        
        render json: schedules, status: :ok
      end
      
      # GET /api/v1/delivery_schedules/:id
      def show
        # Verify the user has permission to see this schedule
        unless can_access_schedule?(@delivery_schedule)
          return render json: { error: "Unauthorized to view this schedule" }, status: :unauthorized
        end
        
        render json: @delivery_schedule, status: :ok
      end
      
      # POST /api/v1/delivery_schedules
      def create
        @delivery_schedule = DeliverySchedule.new(delivery_schedule_params)
        
        if @delivery_schedule.save
          # Create initial delivery assignments based on schedule
          create_delivery_assignments(@delivery_schedule)
          
          render json: @delivery_schedule, status: :created
        else
          render json: { errors: @delivery_schedule.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # PUT/PATCH /api/v1/delivery_schedules/:id
      def update
        if @delivery_schedule.update(delivery_schedule_params)
          # Update future delivery assignments if schedule changed
          update_future_assignments(@delivery_schedule) if schedule_frequency_changed?
          
          render json: @delivery_schedule, status: :ok
        else
          render json: { errors: @delivery_schedule.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/delivery_schedules/:id
      def destroy
        # Delete future assignments when schedule is deleted
        DeliveryAssignment.where(delivery_schedule_id: @delivery_schedule.id, status: 'pending').destroy_all
        
        @delivery_schedule.destroy
        head :no_content
      end
      
      private
      
      def set_delivery_schedule
        @delivery_schedule = DeliverySchedule.find(params[:id])
      end
      
      def delivery_schedule_params
        params.permit(
          :customer_id, 
          :user_id, 
          :frequency, 
          :start_date,
          :end_date,
          :status
        )
      end
      
      def ensure_admin
        unless current_user.admin?
          render json: { error: "Only administrators can manage delivery schedules" }, status: :unauthorized
        end
      end
      
      def can_access_schedule?(schedule)
        return true if current_user.admin?
        return true if current_user.delivery_person? && schedule.user_id == current_user.id
        
        customer = Customer.find_by(user_id: current_user.id)
        return customer && schedule.customer_id == customer.id
      end
      
      def create_delivery_assignments(schedule)
        # This is a simplified version - you might want to add more logic
        # to handle different frequencies (daily, weekly, monthly)
        current_date = schedule.start_date
        end_date = schedule.end_date || (current_date + 30.days) # Default 30 days if no end date
        
        while current_date <= end_date
          DeliveryAssignment.create!(
            delivery_schedule_id: schedule.id,
            customer_id: schedule.customer_id,
            user_id: schedule.user_id,
            scheduled_date: current_date,
            status: 'pending',
            unit: params["unit"],
            product_id: params["product_id"].to_i,
            quantity: params["quantity"].to_i
          )
          # Increment based on frequency
          case schedule.frequency
          when 'daily'
            current_date += 1.day
          when 'weekly'
            current_date += 1.week
          when 'monthly'
            current_date += 1.month
          else
            current_date += 1.day # Default to daily
          end
        end
      end
      
      def update_future_assignments(schedule)
        # Delete pending assignments and recreate them
        DeliveryAssignment.where(delivery_schedule_id: schedule.id, status: 'pending').destroy_all
        create_delivery_assignments(schedule)
      end
      
      def schedule_frequency_changed?
        @delivery_schedule.saved_changes.keys.intersect?(['frequency', 'start_date', 'end_date', 'user_id'])
      end
    end
  end
end