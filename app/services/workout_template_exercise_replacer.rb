# Replaces a template's exercises with the given list, all or nothing. This is
# how the web saves a template: it edits a draft locally and sends the whole
# result once, rather than writing each change as it is made.
#
# Positions are assigned from the order of the list (A, B, C...), so gaps left
# by removed exercises disappear on save. Each exercise must be one the coach
# could pick for a workout (Exercise.selectable); anything else raises
# RecordNotFound without having changed the template.
class WorkoutTemplateExerciseReplacer
  PRESCRIPTION_KEYS = %i[sets reps rest_seconds rir weight notes].freeze

  def self.call(template:, coach:, items:)
    new(template, coach, items).call
  end

  def initialize(template, coach, items)
    @template = template
    @coach = coach
    @items = items
  end

  def call
    exercises = find_exercises
    ensure_it_fits

    ActiveRecord::Base.transaction do
      @template.workout_template_exercises.destroy_all
      @items.each_with_index do |item, index|
        @template.workout_template_exercises.create!(
          item.slice(*PRESCRIPTION_KEYS).merge(
            exercise: exercises.fetch(item[:exercise_id].to_i),
            position: WorkoutTemplateExercise::POSITIONS[index]
          )
        )
      end
    end

    @template.workout_template_exercises.reset
    @template
  end

  private

  def find_exercises
    ids = @items.map { |item| item[:exercise_id].to_i }.uniq
    found = Exercise.selectable(@coach.id).where(id: ids).index_by(&:id)
    raise ActiveRecord::RecordNotFound, "Exercise not found" unless (ids - found.keys).empty?

    found
  end

  def ensure_it_fits
    return if @items.size <= WorkoutTemplateExercise::POSITIONS.size

    @template.errors.add(:base, "A template holds at most #{WorkoutTemplateExercise::POSITIONS.size} exercises")
    raise ActiveRecord::RecordInvalid, @template
  end
end
