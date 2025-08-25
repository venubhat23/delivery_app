class AddIndexesForMilkAnalyticsPerformance < ActiveRecord::Migration[8.0]
  def change
    # Indexes for procurement_assignments to improve milk analytics queries
    add_index :procurement_assignments, [:user_id, :date], name: 'index_procurement_assignments_on_user_and_date'
    add_index :procurement_assignments, [:vendor_name, :date], name: 'index_procurement_assignments_on_vendor_and_date'
    add_index :procurement_assignments, [:product_id, :date], name: 'index_procurement_assignments_on_product_and_date'
    add_index :procurement_assignments, [:user_id, :vendor_name, :date], name: 'index_procurement_assignments_composite'
    add_index :procurement_assignments, [:status, :date], name: 'index_procurement_assignments_on_status_and_date'
    
    # Indexes for procurement_schedules
    add_index :procurement_schedules, [:user_id, :from_date, :to_date], name: 'index_procurement_schedules_on_user_and_dates'
    add_index :procurement_schedules, [:product_id, :status], name: 'index_procurement_schedules_on_product_and_status'
    add_index :procurement_schedules, [:vendor_name, :status], name: 'index_procurement_schedules_on_vendor_and_status'
    
    # Indexes for delivery_assignments to improve analytics
    add_index :delivery_assignments, [:scheduled_date, :status], name: 'index_delivery_assignments_on_date_and_status'
    add_index :delivery_assignments, [:product_id, :scheduled_date, :status], name: 'index_delivery_assignments_composite'
    add_index :delivery_assignments, [:customer_id, :scheduled_date], name: 'index_delivery_assignments_on_customer_and_date'
    
    # Add partial indexes for common queries (PostgreSQL specific - will be ignored on other DBs)
    if ActiveRecord::Base.connection.adapter_name.downcase == 'postgresql'
      # Index only completed delivery assignments
      add_index :delivery_assignments, [:scheduled_date, :product_id], 
                where: "status = 'completed'",
                name: 'index_delivery_assignments_completed'
      
      # Index only active procurement schedules
      add_index :procurement_schedules, [:from_date, :to_date, :user_id],
                where: "status = 'active'", 
                name: 'index_procurement_schedules_active'
    end
    
    # Indexes for products table if exists
    if table_exists?(:products)
      add_index :products, :name, name: 'index_products_on_name' unless index_exists?(:products, :name)
    end
    
    # Indexes for customers table if exists  
    if table_exists?(:customers)
      add_index :customers, :name, name: 'index_customers_on_name' unless index_exists?(:customers, :name)
    end
  end
end
