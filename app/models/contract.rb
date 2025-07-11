class Contract < ApplicationRecord
  belongs_to :user
  
  validates :description, presence: true
  validates :status, inclusion: { in: %w[pending processing completed failed] }
  
  before_create :set_default_status
  
  private
  
  def set_default_status
    self.status = 'pending' if status.blank?
  end
end