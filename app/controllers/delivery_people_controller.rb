# class DeliveryPeopleController < ApplicationController
#   before_action :require_login
#   before_action :set_delivery_person, only: [:show, :edit, :update, :destroy, :assign_customers, :update_assignments]

#   def index
#     @delivery_people = User.delivery_people.includes(:assigned_customers)
#     @total_delivery_people = @delivery_people.count
#     @total_assigned_customers = Customer.assigned.count
#     @unassigned_customers = Customer.unassigned.count
#   end

#   def show
#     @assigned_customers = @delivery_person.assigned_customers.includes(:user)
#     # @recent_deliveries = @delivery_person.deliveries.includes(:customer).retext_fieldtext_fieldcent.limit(10)
#   end

#   def new
#     @delivery_person = User.new(role: 'delivery_person')
#   end

#   def create
#     @delivery_person = User.new(delivery_person_params)
#     @delivery_person.role = 'delivery_person'
    
#     if @delivery_person.save
#       redirect_to delivery_person_path(@delivery_person), notice: 'Delivery person was successfully created.'
#     else
#       render :new, status: :unprocessable_entity
#     end
#   end

#   def edit
#   end

#   def update
#     if @delivery_person.update(delivery_person_params)
#       redirect_to @delivery_person, notice: 'Delivery person was successfully updated.'
#     else
#       render :edit, status: :unprocessable_entity
#     end
#   end

#   def destroy
#     # Unassign all customers before deleting
#     @delivery_person.assigned_customers.update_all(delivery_person_id: nil)
#     @delivery_person.destroy
#     redirect_to delivery_people_url, notice: 'Delivery person was successfully deleted.'
#   end

#   def assign_customers
#     @assigned_customers = @delivery_person.assigned_customers
#     @available_customers = Customer.unassigned.includes(:user)
#     @current_count = @assigned_customers.count
#     @available_slots = @delivery_person.available_customer_slots
#   end

#   def update_assignments
#     customer_ids = params[:customer_ids] || []
    
#     # Validate capacity
#     total_after_assignment = @delivery_person.assigned_customers.count + customer_ids.length
    
#     if total_after_assignment > 50
#       redirect_to assign_customers_delivery_person_path(@delivery_person), 
#                   alert: "Cannot assign customers. This would exceed the limit of 50 customers per delivery person."
#       return
#     end

#     begin
#       ActiveRecord::Base.transaction do
#         # Assign selected customers
#         Customer.where(id: customer_ids).each do |customer|
#           next if customer.delivery_person.present?
          
#           customer.update!(delivery_person: @delivery_person)
#         end
#       end

#       assigned_count = customer_ids.length
#       redirect_to assign_customers_delivery_person_path(@delivery_person), 
#                   notice: "Successfully assigned #{assigned_count} customer(s) to #{@delivery_person.name}."
                  
#     rescue ActiveRecord::RecordInvalid => e
#       redirect_to assign_customers_delivery_person_path(@delivery_person), 
#                   alert: "Error assigning customers: #{e.message}"
#     end
#   end

#   def unassign_customer
#     customer = Customer.find(params[:customer_id])
    
#     if customer.delivery_person == @delivery_person
#       customer.update(delivery_person: nil)
#       redirect_to assign_customers_delivery_person_path(@delivery_person), notice: "Customer #{customer.name} has been unassigned."
#     else
#       redirect_to assign_customers_delivery_person_path(@delivery_person), alert: "Customer not found or not assigned to this delivery person."
#     end
#   end

#   # Bulk operations
#   def bulk_assign
#     delivery_person_id = params[:delivery_person_id]
#     customer_ids = params[:customer_ids] || []
    
#     delivery_person = User.delivery_people.find(delivery_person_id)
    
#     # Check capacity
#     current_count = delivery_person.assigned_customers.count
#     if current_count + customer_ids.length > 50
#       render json: { 
#         success: false, 
#         message: "Cannot assign #{customer_ids.length} customers. Delivery person has #{50 - current_count} slots available." 
#       }
#       return
#     end

#     begin
#       ActiveRecord::Base.transaction do
#         Customer.where(id: customer_ids, delivery_person_id: nil)
#                 .update_all(delivery_person_id: delivery_person_id)
#       end

#       render json: { 
#         success: true, 
#         message: "Successfully assigned #{customer_ids.length} customers to #{delivery_person.name}.",
#         assigned_count: customer_ids.length
#       }
#     rescue => e
#       render json: { success: false, message: "Error: #{e.message}" }
#     end
#   end

#   def statistics
#     @stats = {
#       total_delivery_people: User.delivery_people.count,
#       active_delivery_people: User.delivery_people.joins(:assigned_customers).distinct.count,
#       total_customers: Customer.count,
#       assigned_customers: Customer.assigned.count,
#       unassigned_customers: Customer.unassigned.count,
#       average_customers_per_person: Customer.assigned.count.to_f / [User.delivery_people.count, 1].max,
#       capacity_utilization: (Customer.assigned.count.to_f / (User.delivery_people.count * 200) * 100).round(2)
#     }
#   end

#   private

#   def set_delivery_person
#     @delivery_person = User.delivery_people.find(params[:id])
#   rescue ActiveRecord::RecordNotFound
#     redirect_to delivery_people_path, alert: 'Delivery person not found.'
#   end

#   def delivery_person_params
#     params.require(:user).permit(:name, :email, :phone, :password, :password_confirmation)
#   end
# end

class DeliveryPeopleController < ApplicationController
  before_action :require_login
  before_action :set_delivery_person, only: [:show, :edit, :update, :destroy, :assign_customers, :update_assignments, :manage_customers, :update_customer_assignments]

  def index
    @delivery_people = User.delivery_people.includes(:assigned_customers)
    @total_delivery_people = @delivery_people.count
    @total_assigned_customers = Customer.assigned.count
    @unassigned_customers = Customer.unassigned.count
    
    respond_to do |format|
      format.html # render index.html.erb
      format.json do
        render json: @delivery_people.map { |dp|
          {
            id: dp.id,
            name: dp.name,
            email: dp.email,
            phone: dp.phone,
            customer_count: dp.assigned_customers.count,
            available_slots: dp.available_customer_slots
          }
        }
      end
    end
  end

  def show
    @assigned_customers = @delivery_person.assigned_customers.includes(:user)
    # @recent_deliveries = @delivery_person.deliveries.includes(:customer).retext_fieldtext_fieldcent.limit(10)
  end

  def new
    @delivery_person = User.new(role: 'delivery_person')
  end

  def create
    @delivery_person = User.new(delivery_person_params)
    @delivery_person.role = 'delivery_person'
    
    if @delivery_person.save
      redirect_to delivery_person_path(@delivery_person), notice: 'Delivery person was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @delivery_person.update(delivery_person_params)
      redirect_to delivery_person_path(@delivery_person), notice: 'Delivery person was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # Unassign all customers before deleting
    @delivery_person.assigned_customers.update_all(delivery_person_id: nil)
    @delivery_person.destroy
    redirect_to delivery_people_url, notice: 'Delivery person was successfully deleted.'
  end

  def assign_customers
    @assigned_customers = @delivery_person.assigned_customers
    @available_customers = Customer.unassigned.includes(:user)
    @current_count = @assigned_customers.count
    @available_slots = @delivery_person.available_customer_slots
  end

  def update_assignments
    customer_ids = params[:customer_ids] || []
    
    # Validate capacity
    total_after_assignment = @delivery_person.assigned_customers.count + customer_ids.length
    
    if total_after_assignment > 200
      redirect_to assign_customers_delivery_person_path(@delivery_person), 
                  alert: "Cannot assign customers. This would exceed the limit of 200 customers per delivery person."
      return
    end

    begin
      ActiveRecord::Base.transaction do
        # Assign selected customers
        Customer.where(id: customer_ids).each do |customer|
          next if customer.delivery_person.present?
          
          customer.update!(delivery_person: @delivery_person)
        end
      end

      assigned_count = customer_ids.length
      redirect_to assign_customers_delivery_person_path(@delivery_person), 
                  notice: "Successfully assigned #{assigned_count} customer(s) to #{@delivery_person.name}."
                  
    rescue ActiveRecord::RecordInvalid => e
      redirect_to assign_customers_delivery_person_path(@delivery_person), 
                  alert: "Error assigning customers: #{e.message}"
    end
  end

  # New action to manage assigned customers
  def manage_customers
    @assigned_customers = @delivery_person.assigned_customers.includes(:user)
    @current_count = @assigned_customers.count
    @available_slots = @delivery_person.available_customer_slots
  end

  # New action to update customer assignments (unassign customers)
  def update_customer_assignments
    customer_ids_to_keep = params[:customer_ids] || []
    
    begin
      ActiveRecord::Base.transaction do
        # Get all currently assigned customers
        currently_assigned = @delivery_person.assigned_customers.pluck(:id)
        
        # Find customers to unassign (those not in the submitted list)
        @customers_to_unassign = currently_assigned - customer_ids_to_keep.map(&:to_i)
        # Unassign customers that were unchecked
        if @customers_to_unassign.any?
          Customer.where(id: @customers_to_unassign).update_all(delivery_person_id: nil)
        end
      end

      unassigned_count = (@delivery_person.assigned_customers.count - customer_ids_to_keep.length).abs
      if @customers_to_unassign.count > 0
        redirect_to manage_customers_delivery_person_path(@delivery_person), 
                    notice: "Successfully unassigned #{@customers_to_unassign.count} customer(s) from #{@delivery_person.name}."
      else
        redirect_to manage_customers_delivery_person_path(@delivery_person), 
                    notice: "No changes made to customer assignments."
      end
                    
    rescue ActiveRecord::RecordInvalid => e
      redirect_to manage_customers_delivery_person_path(@delivery_person), 
                  alert: "Error updating customer assignments: #{e.message}"
    end
  end

  def unassign_customer
    customer = Customer.find(params[:customer_id])
    
    if customer.delivery_person == @delivery_person
      customer.update(delivery_person: nil)
      redirect_to assign_customers_delivery_person_path(@delivery_person), notice: "Customer #{customer.name} has been unassigned."
    else
      redirect_to assign_customers_delivery_person_path(@delivery_person), alert: "Customer not found or not assigned to this delivery person."
    end
  end

  # Bulk operations
  def bulk_assign
    delivery_person_id = params[:delivery_person_id]
    customer_ids = params[:customer_ids] || []
    
    delivery_person = User.delivery_people.find(delivery_person_id)
    
    # Check capacity
    current_count = delivery_person.assigned_customers.count
    if current_count + customer_ids.length > 200
      render json: { 
        success: false, 
        message: "Cannot assign #{customer_ids.length} customers. Delivery person has #{200 - current_count} slots available." 
      }
      return
    end

    begin
      ActiveRecord::Base.transaction do
        Customer.where(id: customer_ids, delivery_person_id: nil)
                .update_all(delivery_person_id: delivery_person_id)
      end

      render json: { 
        success: true, 
        message: "Successfully assigned #{customer_ids.length} customers to #{delivery_person.name}.",
        assigned_count: customer_ids.length
      }
    rescue => e
      render json: { success: false, message: "Error: #{e.message}" }
    end
  end

  def statistics
    @stats = {
      total_delivery_people: User.delivery_people.count,
      active_delivery_people: User.delivery_people.joins(:assigned_customers).distinct.count,
      total_customers: Customer.count,
      assigned_customers: Customer.assigned.count,
      unassigned_customers: Customer.unassigned.count,
      average_customers_per_person: Customer.assigned.count.to_f / [User.delivery_people.count, 1].max,
      capacity_utilization: (Customer.assigned.count.to_f / (User.delivery_people.count * 200) * 100).round(2)
    }
  end

  private

  def set_delivery_person
    @delivery_person = User.delivery_people.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to delivery_people_path, alert: 'Delivery person not found.'
  end

  def delivery_person_params
    params.require(:user).permit(:name, :email, :phone, :password, :password_confirmation)
  end
end