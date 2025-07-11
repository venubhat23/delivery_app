class Contract < ApplicationRecord
  validates :name, presence: true
  validates :content, presence: true
  validates :status, presence: true, inclusion: { in: %w[draft sent active completed cancelled] }
  
  scope :by_status, ->(status) { where(status: status) }
  scope :recent, -> { order(created_at: :desc) }
  
  def status_color
    case status
    when 'draft'
      'secondary'
    when 'sent'
      'info'
    when 'active'
      'success'
    when 'completed'
      'primary'
    when 'cancelled'
      'danger'
    else
      'secondary'
    end
  end
end