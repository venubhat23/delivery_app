class CreateContracts < ActiveRecord::Migration[7.0]
  def change
    create_table :contracts do |t|
      t.string :name, null: false
      t.text :content, null: false
      t.string :status, default: 'draft'
      
      t.timestamps
    end
    
    add_index :contracts, :status
    add_index :contracts, :created_at
  end
end