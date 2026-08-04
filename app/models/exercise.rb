class Exercise < ApplicationRecord
  DEFAULT_LOCALE = "en".freeze
  PRESCRIPTION_TYPES = %w[repetitions].freeze

  belongs_to :coach, class_name: "User", optional: true

  has_many :workout_exercises, dependent: :destroy

  # `through:` associations let an exercise reach muscles and equipment via the
  # join tables, so `exercise.muscles` reads naturally while the join row still
  # carries extra data (the primary/secondary role).
  has_many :exercise_muscles, dependent: :destroy
  has_many :muscles, through: :exercise_muscles
  has_many :exercise_equipment, class_name: "ExerciseEquipment", dependent: :destroy
  has_many :equipment, through: :exercise_equipment
  has_many :exercise_translations, dependent: :destroy
  has_many :exercise_media, class_name: "ExerciseMedium", dependent: :destroy

  # `name` and `muscle_group` are the pre-catalog flat columns. They are still
  # NOT NULL and still power the current API, so they stay required until
  # Stage 5 moves the contract onto translations and muscles.
  validates :name, presence: true
  validates :muscle_group, presence: true
  validates :prescription_type, presence: true, inclusion: { in: PRESCRIPTION_TYPES }
  validates :source_uid, uniqueness: { scope: :source }, allow_nil: true
  validate :custom_requires_coach
  validate :catalog_cannot_have_coach
  validate :provider_identity_is_complete
  validate :custom_cannot_have_provider_identity

  scope :catalog, -> { where(is_custom: false) }
  scope :custom, -> { where(is_custom: true) }
  scope :for_coach, ->(coach_id) { where(is_custom: false).or(where(coach_id: coach_id)) }
  scope :active, -> { where(active: true) }
  scope :assignable, -> { where(assignable: true) }
  scope :from_source, ->(source) { where(source: source) }

  # The picker scope: what a coach may put into a new workout.
  #
  # Deliberately separate from `for_coach`, which is also used to look up an
  # exercise a program already references and must keep resolving after a
  # record is deactivated — otherwise a client's history would break when the
  # provider drops an exercise.
  #
  # STAGE 5 MUST switch the exercise index endpoints onto this scope and add
  # pagination before any provider sync populates the catalog. Today both index
  # actions use `for_coach` with no limit, which is fine for a hand-seeded
  # catalog of a few dozen rows and is not fine for 1327.
  scope :selectable, ->(coach_id) { for_coach(coach_id).active.assignable }

  def custom?
    is_custom?
  end

  def from_provider?
    source.present?
  end

  # Returns the translation for `locale`, falling back to English, then to
  # whatever translation exists. Returns nil only when an exercise has no
  # translations at all, which is true of every legacy row until Stage 2.
  def translation_for(locale)
    requested = locale.presence&.to_s
    by_locale = exercise_translations.index_by(&:locale)

    by_locale[requested] || by_locale[DEFAULT_LOCALE] || exercise_translations.first
  end

  # Localized name with the same fallback chain, ending at the legacy `name`
  # column so this is safe to call on a pre-catalog record.
  def localized_name(locale)
    translation_for(locale)&.name.presence || name
  end

  def primary_muscle
    exercise_muscles.detect { |link| link.role == "primary" }&.muscle
  end

  def secondary_muscles
    exercise_muscles.select { |link| link.role == "secondary" }.map(&:muscle)
  end

  def animation
    exercise_media.select(&:animation?).min_by(&:position)
  end

  private

  def custom_requires_coach
    if is_custom? && coach_id.blank?
      errors.add(:coach_id, "is required for custom exercises")
    end
  end

  def catalog_cannot_have_coach
    if !is_custom? && coach_id.present?
      errors.add(:coach_id, "must be blank for catalog exercises")
    end
  end

  def provider_identity_is_complete
    return if source.blank? && source_uid.blank?
    return if source.present? && source_uid.present?

    errors.add(:source_uid, "and source must be set together")
  end

  def custom_cannot_have_provider_identity
    if is_custom? && source.present?
      errors.add(:source, "must be blank for custom exercises")
    end
  end
end
