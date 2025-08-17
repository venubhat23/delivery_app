class SupportTicket < ApplicationRecord
  belongs_to :customer

  validates :subject, presence: true, length: { maximum: 255 }
  validates :message, presence: true, length: { maximum: 5000 }
  validates :channel, presence: true, inclusion: { in: %w[app web email phone] }
  validates :status, presence: true, inclusion: { in: %w[open in_progress resolved closed] }
  validates :external_id, uniqueness: true, allow_blank: true

  scope :open, -> { where(status: 'open') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :resolved, -> { where(status: 'resolved') }
  scope :closed, -> { where(status: 'closed') }
  scope :active, -> { where(status: ['open', 'in_progress']) }
  scope :by_channel, ->(channel) { where(channel: channel) }
  scope :recent, -> { order(created_at: :desc) }

  def open?
    status == 'open'
  end

  def in_progress?
    status == 'in_progress'
  end

  def resolved?
    status == 'resolved'
  end

  def closed?
    status == 'closed'
  end

  def active?
    ['open', 'in_progress'].include?(status)
  end

  def mark_as_in_progress!
    update!(status: 'in_progress')
  end

  def mark_as_resolved!
    update!(status: 'resolved')
  end

  def mark_as_closed!
    update!(status: 'closed')
  end

  def reopen!
    update!(status: 'open')
  end

  def days_open
    (Date.current - created_at.to_date).to_i
  end

  def priority
    case days_open
    when 0..1
      'low'
    when 2..4
      'medium'
    when 5..7
      'high'
    else
      'critical'
    end
  end

  def self.status_counts
    group(:status).count
  end

  def self.channel_counts
    group(:channel).count
  end
end