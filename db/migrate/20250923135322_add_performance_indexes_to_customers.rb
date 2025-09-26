class AddPerformanceIndexesToCustomers < ActiveRecord::Migration[8.0]
  def change
    # Critical indexes for delivery_assignments for customer patterns query
    add_index :delivery_assignments, [:customer_id, :scheduled_date], name: 'index_delivery_assignments_on_customer_and_date' unless index_exists?(:delivery_assignments, [:customer_id, :scheduled_date], name: 'index_delivery_assignments_on_customer_and_date')
    add_index :delivery_assignments, [:scheduled_date, :customer_id], name: 'index_delivery_assignments_on_date_and_customer' unless index_exists?(:delivery_assignments, [:scheduled_date, :customer_id], name: 'index_delivery_assignments_on_date_and_customer')
    add_index :delivery_assignments, :product_id, name: 'index_delivery_assignments_on_product_id' unless index_exists?(:delivery_assignments, :product_id, name: 'index_delivery_assignments_on_product_id')

    # Composite index for the most common customer patterns query
    add_index :delivery_assignments, [:customer_id, :scheduled_date, :product_id], name: 'index_da_on_customer_date_product' unless index_exists?(:delivery_assignments, [:customer_id, :scheduled_date, :product_id], name: 'index_da_on_customer_date_product')
  end

  def down
    remove_index :customers, name: 'index_customers_on_is_active' if index_exists?(:customers, :is_active, name: 'index_customers_on_is_active')
    remove_index :customers, name: 'index_customers_on_delivery_person_id' if index_exists?(:customers, :delivery_person_id, name: 'index_customers_on_delivery_person_id')
    remove_index :customers, name: 'index_customers_on_user_id' if index_exists?(:customers, :user_id, name: 'index_customers_on_user_id')
    remove_index :customers, name: 'index_customers_on_is_active_and_name' if index_exists?(:customers, [:is_active, :name], name: 'index_customers_on_is_active_and_name')
    remove_index :customers, name: 'index_customers_on_phone_number' if index_exists?(:customers, :phone_number, name: 'index_customers_on_phone_number')
    remove_index :customers, name: 'index_customers_on_email' if index_exists?(:customers, :email, name: 'index_customers_on_email')
    remove_index :customers, name: 'index_customers_on_member_id' if index_exists?(:customers, :member_id, name: 'index_customers_on_member_id')
    remove_index :customers, name: 'index_customers_on_is_active_and_delivery_person_id' if index_exists?(:customers, [:is_active, :delivery_person_id], name: 'index_customers_on_is_active_and_delivery_person_id')

    execute "DROP INDEX CONCURRENTLY IF EXISTS index_customers_on_name_trgm;" rescue nil
    execute "DROP INDEX CONCURRENTLY IF EXISTS index_customers_on_address_trgm;" rescue nil
  end
end
