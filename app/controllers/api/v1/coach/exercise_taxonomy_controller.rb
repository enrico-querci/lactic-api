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
        include Localizable

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

        # Sorted after translating, not in SQL: an Italian dropdown ordered
        # by the underlying English name (the old `.order(:name)`) would read
        # as nonsense — Deltoidi, Avambracci, Glutei, Ischiocrurali, Dorsali.
        def muscles
          Muscle.where(id: ExerciseMuscle.select(:muscle_id))
                .map { |muscle| { key: muscle.key, name: muscle_label(muscle.name), region: muscle.region } }
                .sort_by { |muscle| muscle[:name] }
        end

        def equipment
          Equipment.where(id: ExerciseEquipment.select(:equipment_id))
                   .map { |item| { key: item.key, name: equipment_label(item.name) } }
                   .sort_by { |item| item[:name] }
        end

        def muscle_label(name) = Catalog::Translation::TaxonomyLabels.muscle(name, current_locale)
        def equipment_label(name) = Catalog::Translation::TaxonomyLabels.equipment(name, current_locale)

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
