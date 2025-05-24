# db/migrate/add_invoice_generated_to_delivery_assignments.rb
class AddInvoiceGeneratedToDeliveryAssignments < ActiveRecord::Migration[8.0]
  def change
    add_column :delivery_assignments, :invoice_generated, :boolean, default: false
    add_column :delivery_assignments, :invoice_id, :bigint, null: true
    add_index :delivery_assignments, :invoice_generated
    add_index :delivery_assignments, :invoice_id
    add_foreign_key :delivery_assignments, :invoices, column: :invoice_id
  end
end