# One media reference for an exercise. Named ExerciseMedium because Rails
# singularizes the `exercise_media` table that way; the plan's table name is
# preserved.
#
# `provider_url` must never be serialized to a client. Stage 4 exposes a Lactic
# endpoint that adds the server-side provider key and streams the bytes.
class ExerciseMedium < ApplicationRecord
  KINDS = %w[animation image video].freeze

  belongs_to :exercise

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :position, uniqueness: { scope: %i[exercise_id kind] }

  scope :animations, -> { where(kind: "animation") }
  scope :ordered, -> { order(position: :asc) }

  def animation?
    kind == "animation"
  end
end
