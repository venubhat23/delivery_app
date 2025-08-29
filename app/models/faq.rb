class Faq < ApplicationRecord
  belongs_to :customer, optional: true
  
  validates :question, presence: true, length: { maximum: 1000 }
  validates :answer, presence: true, length: { maximum: 5000 }, if: :admin_answered?
  validates :locale, presence: true, inclusion: { in: %w[en hi te ta kn ml] }
  validates :category, length: { maximum: 100 }
  validates :sort_order, numericality: { greater_than_or_equal_to: 0 }
  
  enum :status, { 
    pending: 0, 
    approved: 1, 
    rejected: 2, 
    answered: 3 
  }

  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :by_locale, ->(locale) { where(locale: locale) }
  scope :for_locale, ->(locale) { where(locale: locale) }
  scope :by_category, ->(category) { where(category: category) }
  scope :ordered, -> { order(:sort_order, :created_at) }
  scope :recent, -> { order(created_at: :desc) }
  scope :user_submitted, -> { where(submitted_by_user: true) }
  scope :admin_created, -> { where(submitted_by_user: [false, nil]) }
  scope :published, -> { where(status: [:approved, :answered], is_active: true) }

  def active?
    is_active
  end

  def inactive?
    !is_active
  end

  def activate!
    update!(is_active: true)
  end

  def deactivate!
    update!(is_active: false)
  end

  def move_up!
    return unless sort_order > 0
    
    other_faq = self.class.where(category: category, locale: locale, sort_order: sort_order - 1).first
    if other_faq
      other_faq.update!(sort_order: sort_order)
      update!(sort_order: sort_order - 1)
    end
  end

  def move_down!
    other_faq = self.class.where(category: category, locale: locale, sort_order: sort_order + 1).first
    if other_faq
      other_faq.update!(sort_order: sort_order)
      update!(sort_order: sort_order + 1)
    end
  end

  def question_preview(limit = 100)
    question.truncate(limit)
  end

  def answer_preview(limit = 200)
    answer.truncate(limit)
  end

  def self.categories_for_locale(locale = 'en')
    where(locale: locale).distinct.pluck(:category).compact.sort
  end

  def self.available_locales
    distinct.pluck(:locale).sort
  end

  def self.by_category_and_locale(category, locale = 'en')
    active.where(category: category, locale: locale).ordered
  end

  def self.search(query, locale = 'en')
    active.where(locale: locale)
          .where("question ILIKE ? OR answer ILIKE ?", "%#{query}%", "%#{query}%")
          .ordered
  end

  def self.reorder_within_category!(category, locale, faq_ids)
    faq_ids.each_with_index do |faq_id, index|
      where(id: faq_id, category: category, locale: locale).update_all(sort_order: index)
    end
  end

  def admin_answered?
    !submitted_by_user || answered?
  end

  def user_question?
    submitted_by_user == true
  end

  def can_be_published?
    return true unless user_question?
    answered? && answer.present?
  end

  def approve_and_publish!
    update!(status: :approved, is_active: true)
  end

  def answer_question!(answer_text, admin_response = nil)
    update!(
      answer: answer_text,
      admin_response: admin_response,
      status: :answered,
      is_active: true
    )
  end
end