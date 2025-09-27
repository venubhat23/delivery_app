class CustomerPoint < ApplicationRecord
  belongs_to :customer

  validates :points, presence: true, numericality: { greater_than: 0 }
  validates :action_type, presence: true

  scope :by_customer, ->(customer_id) { where(customer_id: customer_id) }
  scope :by_action_type, ->(action_type) { where(action_type: action_type) }
  scope :recent, -> { order(created_at: :desc) }

  ACTION_TYPES = %w[delivery referral assignment schedule].freeze

  def self.total_points_for_customer(customer_id)
    where(customer_id: customer_id).sum(:points)
  end

  def self.award_points(customer:, points:, action_type:, reference: nil, description: nil)
    create!(
      customer: customer,
      points: points,
      action_type: action_type,
      reference_id: reference&.id,
      reference_type: reference&.class&.name,
      description: description
    )
  end
end
