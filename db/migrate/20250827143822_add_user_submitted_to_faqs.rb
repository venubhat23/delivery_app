class AddUserSubmittedToFaqs < ActiveRecord::Migration[8.0]
  def change
    add_reference :faqs, :customer, null: false, foreign_key: true
    add_column :faqs, :submitted_by_user, :boolean
    add_column :faqs, :status, :integer
    add_column :faqs, :admin_response, :text
  end
end
