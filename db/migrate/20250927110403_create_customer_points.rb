class CreateCustomerPoints < ActiveRecord::Migration[8.0]
  def change
    create_table :customer_points do |t|
      t.references :customer, null: false, foreign_key: true
      t.decimal :points, precision: 10, scale: 2, default: 0.0
      t.string :action_type, null: false
      t.integer :reference_id
      t.string :reference_type
      t.text :description

      t.timestamps
    end

    add_index :customer_points, [:customer_id, :action_type]
    add_index :customer_points, [:reference_type, :reference_id]
  end
end
