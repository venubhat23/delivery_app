class AddWhatsappPhoneNumberToProcurementSchedules < ActiveRecord::Migration[8.0]
  def change
    add_column :procurement_schedules, :whatsapp_phone_number, :string
  end
end
