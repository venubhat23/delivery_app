class AddFieldsToSupportTickets < ActiveRecord::Migration[8.0]
  def change
    add_column :support_tickets, :priority, :integer
    add_column :support_tickets, :assigned_to, :integer
    add_column :support_tickets, :resolved_at, :datetime
    add_column :support_tickets, :customer_rating, :integer
    add_column :support_tickets, :customer_feedback, :text
  end
end
