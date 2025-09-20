class AddGinIndexForProductNameSearch < ActiveRecord::Migration[8.0]
  def change
    # Add GIN index for faster ILIKE searches on product names
    enable_extension 'pg_trgm' unless extension_enabled?('pg_trgm')
    add_index :products, :name, using: :gin, opclass: :gin_trgm_ops, name: 'idx_products_name_gin'

    # Add composite index for delivery assignments with milk product filtering
    add_index :delivery_assignments, [:status, :completed_at, :product_id], name: 'idx_delivery_status_completed_product'
  end
end
