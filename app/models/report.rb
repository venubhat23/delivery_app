# app/models/report.rb
class Report < ApplicationRecord
  belongs_to :user
  
  validates :name, presence: true
  validates :report_type, presence: true
  validates :from_date, presence: true
  validates :to_date, presence: true
  
  scope :gst_reports, -> { where(report_type: 'gst') }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
  
  def formatted_date_range
    "#{from_date.strftime('%b %d')} - #{to_date.strftime('%b %d, %Y')}"
  end
  
  def formatted_created_at
    created_at.strftime("%B %d, %Y at %I:%M %p")
  end
end