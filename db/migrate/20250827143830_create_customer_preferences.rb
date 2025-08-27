class CreateCustomerPreferences < ActiveRecord::Migration[8.0]
  def change
    create_table :customer_preferences do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :language
      t.time :delivery_time_start
      t.time :delivery_time_end
      t.boolean :skip_weekends
      t.text :special_instructions
      t.text :notification_preferences

      t.timestamps
    end
  end
end
