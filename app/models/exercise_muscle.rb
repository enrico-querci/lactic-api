class ExerciseMuscle < ApplicationRecord
  ROLES = %w[primary secondary].freeze

  belongs_to :exercise
  belongs_to :muscle

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :muscle_id, uniqueness: { scope: :exercise_id }
  validate :only_one_primary_per_exercise

  scope :primary, -> { where(role: "primary") }
  scope :secondary, -> { where(role: "secondary") }

  private

  # Volume metrics count configured sets against a single primary muscle, so a
  # second primary row would double-count. A partial unique index enforces this
  # in the database as well; this validation turns the race into a readable
  # error in the common case.
  def only_one_primary_per_exercise
    return unless role == "primary"

    conflicting = ExerciseMuscle.where(exercise_id: exercise_id, role: "primary")
    conflicting = conflicting.where.not(id: id) if persisted?
    return unless conflicting.exists?

    errors.add(:role, "primary muscle already set for this exercise")
  end
end
