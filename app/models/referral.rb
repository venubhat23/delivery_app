class Referral < ApplicationRecord
  belongs_to :affiliate
  belongs_to :customer, optional: true

  validates :customer_name, presence: true
  validates :customer_phone, presence: true, format: { with: /\A[0-9+\-\s()]+\z/ }
  validates :customer_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :reward_amount, presence: true, numericality: { greater_than: 0 }

  enum :status, { pending: 0, approved: 1, rejected: 2 }

  scope :recent, -> { order(created_at: :desc) }
  scope :this_month, -> { where(created_at: Date.current.beginning_of_month..Date.current.end_of_month) }
  scope :last_month, -> { where(created_at: Date.current.last_month.beginning_of_month..Date.current.last_month.end_of_month) }

  before_create :set_referred_at
  before_update :set_approval_timestamps

  def approve!
    update!(status: 'approved', approved_at: Time.current)
    affiliate.update_total_earnings!
  end

  def reject!(reason = nil)
    self.notes = reason if reason.present?
    update!(status: 'rejected', rejected_at: Time.current)
  end

  def pending_days
    return 0 unless pending?
    (Date.current - created_at.to_date).to_i
  end

  def can_be_approved?
    pending? && customer_name.present? && customer_phone.present?
  end

  private

  def set_referred_at
    self.referred_at = Time.current if referred_at.nil?
  end

  def set_approval_timestamps
    if status_changed?
      case status
      when 'approved'
        self.approved_at = Time.current if approved_at.nil?
      when 'rejected'
        self.rejected_at = Time.current if rejected_at.nil?
      end
    end
  end
end
