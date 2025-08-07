class AddUrlToAdvertisements < ActiveRecord::Migration[7.0]
  def change
    add_column :advertisements, :url, :string
  end
end