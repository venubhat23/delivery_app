class DeliveryAssignment < ApplicationRecord
  def self.generate_delivery_assignments_for_schedule(schedule)
    assignments = []
    current_date = schedule.start_date
    assignments_created = 0
    today = Date.current
    
    while current_date <= schedule.end_date
      # Determine status based on whether the date is in the past
      assignment_status = current_date < today ? 'completed' : 'pending'
      
      assignment = DeliveryAssignment.new(
        delivery_schedule: schedule,
        customer: schedule.customer,
        user: schedule.user,
        product: schedule.product,
        scheduled_date: current_date,
        status: assignment_status,
        quantity: schedule.default_quantity,
        unit: schedule.default_unit || 'pieces'
      )
      
      if assignment.save
        assignments_created += 1
      end
      
      current_date += 1.day
    end
    
    assignments_created
  end
end