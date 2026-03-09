class WorkoutDuplicator
  def self.call(workout:, target_week:, day: nil)
    new(workout, target_week, day).call
  end

  def initialize(workout, target_week, day)
    @workout = workout
    @target_week = target_week
    @day = day || workout.day
  end

  def call
    new_workout = @workout.dup
    new_workout.week = @target_week
    new_workout.day = @day
    new_workout.name = @workout.name

    ActiveRecord::Base.transaction do
      new_workout.save!

      @workout.workout_exercises.each do |we|
        new_we = we.dup
        new_we.workout = new_workout
        new_we.save!
      end
    end

    new_workout
  end
end
