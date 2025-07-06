class AdminSetting < ApplicationRecord
  validates :business_name, presence: true
  validates :mobile, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :account_holder_name, presence: true
  validates :bank_name, presence: true
  validates :account_number, presence: true
  validates :ifsc_code, presence: true
  validates :upi_id, format: { with: /\A[a-zA-Z0-9.\-_]+@[a-zA-Z0-9.\-_]+\z/, message: "must be a valid UPI ID" }, allow_blank: true

  def formatted_terms_and_conditions
    terms_and_conditions.split("\n").map(&:strip).reject(&:empty?)
  end
end