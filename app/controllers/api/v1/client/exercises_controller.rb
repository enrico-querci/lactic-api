module Api
  module V1
    module Client
      class ExercisesController < BaseController
        # GET /api/v1/client/exercises
        def index
          exercises = Exercise.for_coach(current_user.coach_id)
          exercises = exercises.where(muscle_group: params[:muscle_group]) if params[:muscle_group].present?
          exercises = exercises.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
          render json: ExerciseBlueprint.render(exercises)
        end

        # GET /api/v1/client/exercises/:id
        def show
          exercise = Exercise.for_coach(current_user.coach_id).find(params[:id])
          render json: ExerciseBlueprint.render(exercise)
        end

        # GET /api/v1/client/exercises/:id/history
        def history
          exercise = Exercise.for_coach(current_user.coach_id).find(params[:id])

          set_logs = SetLog.joins(exercise_log: { workout_session: {}, workout_exercise: {} })
                          .where(workout_sessions: { client_id: current_user.id })
                          .where(workout_exercises: { exercise_id: exercise.id })
                          .order("workout_sessions.started_at DESC, set_logs.position ASC")

          render json: SetLogBlueprint.render(set_logs)
        end
      end
    end
  end
end
