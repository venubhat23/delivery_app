class CmsPage < ApplicationRecord
  validates :slug, presence: true, uniqueness: { scope: :locale }
  validates :version, presence: true
  validates :title, presence: true, length: { maximum: 255 }
  validates :content, presence: true
  validates :locale, presence: true, inclusion: { in: %w[en hi te ta kn ml] }

  scope :published, -> { where.not(published_at: nil) }
  scope :unpublished, -> { where(published_at: nil) }
  scope :by_locale, ->(locale) { where(locale: locale) }
  scope :for_locale, ->(locale) { where(locale: locale) }
  scope :by_slug, ->(slug) { where(slug: slug) }
  scope :for_slug, ->(slug) { where(slug: slug) }
  scope :recent, -> { order(updated_at: :desc) }

  before_validation :generate_slug, if: -> { slug.blank? && title.present? }
  before_validation :set_default_version, if: -> { version.blank? }

  def published?
    published_at.present? && published_at <= Time.current
  end

  def draft?
    published_at.nil?
  end

  def publish!
    update!(published_at: Time.current)
  end

  def unpublish!
    update!(published_at: nil)
  end

  def schedule_publish!(datetime)
    update!(published_at: datetime)
  end

  def content_preview(limit = 200)
    strip_html_tags(content).truncate(limit)
  end

  def to_param
    slug
  end

  def self.find_by_slug_and_locale(slug, locale = 'en')
    published.find_by(slug: slug, locale: locale)
  end

  def self.available_locales
    distinct.pluck(:locale).sort
  end

  def self.latest_version(slug, locale = 'en')
    where(slug: slug, locale: locale).order(:version).last
  end

  private

  def generate_slug
    self.slug = title.parameterize
  end

  def set_default_version
    self.version = 'v1.0'
  end

  def strip_html_tags(content)
    ActionController::Base.helpers.strip_tags(content)
  end
end