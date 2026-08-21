# The stable Lactic exercise contract.
#
# Nothing here is named after a provider field. `animation_url` points at a
# Lactic endpoint, never at the upstream media URL, and `provider_url` is never
# serialized.
#
# The default view is the list representation. Instruction arrays and secondary
# muscles live in `:detail` only — returning a few hundred full instruction
# arrays in a list response is exactly what the plan warns against.
#
# LEGACY FIELDS: `muscle_group`, `video_url` and `thumbnail_url` are still
# emitted so the deployed web client keeps working. Stage 6 migrates the
# frontend onto `primary_muscle` and `animation_url`, after which they can be
# dropped. `name` needed no such treatment — it is now the localized name,
# which falls back to the legacy column, so old clients see the same string
# they always did and new ones get localization for free.
class ExerciseBlueprint < Blueprinter::Base
  identifier :id

  field :name do |exercise, options|
    exercise.localized_name(options[:locale])
  end

  fields :is_custom, :category, :difficulty, :mechanic, :force,
         :prescription_type, :active, :assignable

  fields :muscle_group, :video_url, :thumbnail_url

  # Only `name` is localized — `key` is the filter value the frontend sends
  # back on exercise-catalog searches (Catalog::ExerciseSearch matches on
  # it), and `region` has no coach/client-facing use today (the glossary's
  # region entries are lowercase prose fragments authored for
  # DescriptionBuilder, not display labels).
  field :primary_muscle do |exercise, options|
    muscle = exercise.primary_muscle
    if muscle
      { key: muscle.key, name: Catalog::Translation::TaxonomyLabels.muscle(muscle.name, options[:locale]), region: muscle.region }
    end
  end

  field :equipment do |exercise, options|
    exercise.equipment.map do |item|
      { key: item.key, name: Catalog::Translation::TaxonomyLabels.equipment(item.name, options[:locale]) }
    end
  end

  field :has_animation do |exercise, _options|
    exercise.animation.present?
  end

  # Resolved by the Lactic animation endpoint, which authenticates the user and
  # streams the bytes with the provider key added server-side. That endpoint
  # arrives in Stage 4; until then this is a well-formed path that 404s, which
  # is why `has_animation` exists for clients to check first.
  field :animation_url do |exercise, _options|
    "/api/v1/exercises/#{exercise.id}/animation" if exercise.animation.present?
  end

  view :detail do
    field :description do |exercise, options|
      exercise.translation_for(options[:locale])&.description
    end

    field :instructions do |exercise, options|
      exercise.translation_for(options[:locale])&.instructions || []
    end

    # The locale actually served, which may differ from the one requested when
    # a translation is missing and the response falls back to English.
    field :locale do |exercise, options|
      exercise.translation_for(options[:locale])&.locale
    end

    field :secondary_muscles do |exercise, options|
      exercise.secondary_muscles.map do |muscle|
        { key: muscle.key, name: Catalog::Translation::TaxonomyLabels.muscle(muscle.name, options[:locale]) }
      end
    end
  end
end
