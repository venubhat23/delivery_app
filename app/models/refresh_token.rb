class RefreshToken < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :customer, optional: true

  validates :token_hash, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :user_agent, length: { maximum: 500 }
  validates :created_by_ip, format: { with: /\A(?:[0-9]{1,3}\.){3}[0-9]{1,3}\z|\A(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}\z/, message: "must be a valid IP address" }, allow_blank: true

  scope :active, -> { where(revoked_at: nil) }
  scope :expired, -> { where('expires_at < ?', Time.current) }
  scope :valid, -> { active.where('expires_at > ?', Time.current) }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_customer, ->(customer) { where(customer: customer) }

  def expired?
    expires_at < Time.current
  end

  def active?
    revoked_at.nil? && !expired?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def replace_with!(new_token_hash)
    update!(replaced_by_token_hash: new_token_hash, revoked_at: Time.current)
  end

  def self.cleanup_expired
    where('expires_at < ?', 1.week.ago).delete_all
  end

  def self.revoke_all_for_user(user)
    where(user: user).update_all(revoked_at: Time.current)
  end

  def self.revoke_all_for_customer(customer)
    where(customer: customer).update_all(revoked_at: Time.current)
  end
end