module Api
  module V1
    module Coach
      # Supplies the values a coach can filter the catalog by.
      #
      # Exists because the filters in Stage 5 take stable keys, and the client
      # cannot invent them. Deriving them in the browser from a page of results
      # would only ever show the muscles that happened to be on that page.
      #
      # Only values that are actually in use are returned, so the UI never
      # offers a filter that would come back empty.
      class ExerciseTaxonomyController < BaseController
        # GET /api/v1/coach/exercise_taxonomy
        def show
          render json: {
            muscles: muscles,
            equipment: equipment,
            categories: distinct(:category),
            difficulties: difficulties
          }
        end

        private

        def muscles
          Muscle.where(id: ExerciseMuscle.select(:muscle_id))
                .order(:name)
                .map { |muscle| { key: muscle.key, name: muscle.name, region: muscle.region } }
        end

        def equipment
          Equipment.where(id: ExerciseEquipment.select(:equipment_id))
                   .order(:name)
                   .map { |item| { key: item.key, name: item.name } }
        end

        # Ordered easiest-first rather than alphabetically, because "advanced,
        # beginner, intermediate" reads as nonsense in a filter. Any value the
        # provider adds later still appears, sorted after the known ones.
        DIFFICULTY_ORDER = %w[beginner intermediate advanced].freeze

        def difficulties
          distinct(:difficulty).sort_by { |value| [ DIFFICULTY_ORDER.index(value) || DIFFICULTY_ORDER.size, value ] }
        end

        def distinct(column)
          visible_exercises.distinct.pluck(column).compact.sort
        end

        def visible_exercises
          Exercise.for_coach(current_user.id)
        end
      end
    end
  end
end
