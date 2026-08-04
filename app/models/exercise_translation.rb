class ExerciseTranslation < ApplicationRecord
  SOURCES = %w[provider machine human].freeze
  LOCALES = %w[en it].freeze

  belongs_to :exercise

  validates :locale, presence: true, inclusion: { in: LOCALES }
  validates :locale, uniqueness: { scope: :exercise_id }
  validates :name, presence: true
  validates :translation_source, presence: true, inclusion: { in: SOURCES }
  validate :instructions_must_be_an_array

  scope :for_locale, ->(locale) { where(locale: locale.to_s) }
  scope :reviewed, -> { where.not(reviewed_at: nil) }

  # A human-reviewed translation must never be replaced by a machine pass.
  # Stage 3 checks this before regenerating Italian.
  def reviewed?
    reviewed_at.present?
  end

  def overwritable_by_sync?
    !reviewed? && translation_source != "human"
  end

  # True when the English content this translation was derived from has since
  # changed. A translation with no recorded source checksum is treated as
  # stale so it gets regenerated once rather than never.
  def stale_for?(current_source_checksum)
    source_checksum.blank? || source_checksum != current_source_checksum
  end

  private

  def instructions_must_be_an_array
    return if instructions.is_a?(Array)

    errors.add(:instructions, "must be an array of ordered steps")
  end
end
