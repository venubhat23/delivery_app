# app/models/report.rb
class Report < ApplicationRecord
  belongs_to :user
  
  validates :name, presence: true
  validates :report_type, presence: true
  validates :from_date, presence: true
  validates :to_date, presence: true
  
  # Serialize content as JSON for milk analytics reports
  serialize :content, JSON
  
  scope :gst_reports, -> { where(report_type: 'gst') }
  scope :milk_analytics_reports, -> { where(report_type: %w[daily_procurement_delivery vendor_performance profit_loss wastage_analysis monthly_summary]) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
  
  def formatted_date_range
    "#{from_date.strftime('%b %d')} - #{to_date.strftime('%b %d, %Y')}"
  end
  
  def formatted_created_at
    created_at.strftime("%B %d, %Y at %I:%M %p")
  end
end