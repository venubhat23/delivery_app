class CreateReports < ActiveRecord::Migration[7.0]
  def change
    create_table :reports do |t|
      t.string :name, null: false
      t.string :report_type, null: false
      t.date :from_date, null: false
      t.date :to_date, null: false
      t.references :user, null: false, foreign_key: true
      t.text :content, null: true
      t.string :file_path, null: true

      t.timestamps
    end

    add_index :reports, [:user_id, :created_at]
    add_index :reports, :report_type
    add_index :reports, [:from_date, :to_date]
  end
end