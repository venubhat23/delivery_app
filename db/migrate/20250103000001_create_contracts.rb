class CreateContracts < ActiveRecord::Migration[8.0]
  def change
    create_table :contracts do |t|
      t.text :description, null: false
      t.text :ai_response
      t.string :status, default: 'pending'
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    
    add_index :contracts, :status
    add_index :contracts, :user_id
  end
end