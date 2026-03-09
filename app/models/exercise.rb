class Exercise < ApplicationRecord
  belongs_to :coach, class_name: "User", optional: true

  has_many :workout_exercises, dependent: :destroy

  validates :name, presence: true
  validates :muscle_group, presence: true
  validate :custom_requires_coach

  scope :catalog, -> { where(is_custom: false) }
  scope :custom, -> { where(is_custom: true) }
  scope :for_coach, ->(coach_id) { where(is_custom: false).or(where(coach_id: coach_id)) }

  private

  def custom_requires_coach
    if is_custom? && coach_id.blank?
      errors.add(:coach_id, "is required for custom exercises")
    end
  end
end
