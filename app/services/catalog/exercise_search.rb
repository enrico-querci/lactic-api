module Catalog
  # Filters, searches and paginates the exercise catalog.
  #
  # Every filter is expressed as a subquery rather than a join, so an exercise
  # matching two muscles or two pieces of equipment still appears once. Joining
  # instead would need `distinct`, which interacts badly with the eager loading
  # this needs to avoid N+1 queries on a 25-record page.
  class ExerciseSearch
    DEFAULT_PER_PAGE = 25
    MAX_PER_PAGE = 100

    Result = Data.define(:records, :total_count, :page, :per_page) do
      def total_pages = per_page.positive? ? (total_count.to_f / per_page).ceil : 0
    end

    def self.call(...) = new(...).call

    def initialize(scope:, params: {})
      @scope = scope
      @params = params
    end

    def call
      relation = filtered
      total = relation.count

      Result.new(
        records: relation.includes(preloads).order(:name, :id).limit(per_page).offset((page - 1) * per_page),
        total_count: total,
        page: page,
        per_page: per_page
      )
    end

    def page
      @page ||= [ @params[:page].to_i, 1 ].max
    end

    def per_page
      @per_page ||= begin
        requested = @params[:per_page].to_i
        requested = DEFAULT_PER_PAGE if requested <= 0
        [ requested, MAX_PER_PAGE ].min
      end
    end

    private

    def preloads
      [ :exercise_translations, :equipment, :exercise_media, { exercise_muscles: :muscle } ]
    end

    def filtered
      relation = @scope
      relation = by_search(relation)
      relation = by_muscle(relation)
      relation = by_equipment(relation)
      relation = by_enum(relation, :category, @params[:category])
      relation = by_enum(relation, :difficulty, @params[:difficulty])
      relation = by_legacy_muscle_group(relation)
      by_ownership(relation)
    end

    # The pre-catalog filter the deployed web client still sends, matching the
    # flat `exercises.muscle_group` column. Kept working until Stage 6 moves
    # the frontend onto the normalized `muscle` key filter.
    def by_legacy_muscle_group(relation)
      value = @params[:muscle_group]
      return relation if value.blank?

      relation.where(muscle_group: value)
    end

    # Searches every stored locale at once, whatever locale the response will
    # be rendered in, so an Italian coach can find an exercise by typing its
    # English name. Also searches `exercises.name` directly, because coach-owned
    # custom exercises have no translation rows.
    def by_search(relation)
      term = @params[:search].to_s.strip
      return relation if term.blank?

      pattern = "%#{sanitize_like(term)}%"
      relation.where(
        "exercises.name ILIKE :q OR EXISTS (" \
        "SELECT 1 FROM exercise_translations t " \
        "WHERE t.exercise_id = exercises.id AND (t.name ILIKE :q OR t.description ILIKE :q))",
        q: pattern
      )
    end

    # `muscle` matches either role; `primary_muscle` restricts to the muscle an
    # exercise actually targets, which is what volume planning counts.
    def by_muscle(relation)
      relation = restrict_to_muscle(relation, @params[:primary_muscle], role: "primary")
      restrict_to_muscle(relation, @params[:muscle], role: nil)
    end

    def restrict_to_muscle(relation, key, role:)
      return relation if key.blank?

      links = ExerciseMuscle.joins(:muscle).where(muscles: { key: key.to_s.strip.downcase })
      links = links.where(role: role) if role

      relation.where(id: links.select(:exercise_id))
    end

    def by_equipment(relation)
      key = @params[:equipment]
      return relation if key.blank?

      links = ExerciseEquipment.joins(:equipment).where(equipment: { key: key.to_s.strip.downcase })
      relation.where(id: links.select(:exercise_id))
    end

    def by_enum(relation, column, value)
      return relation if value.blank?

      relation.where(column => value.to_s.strip.downcase)
    end

    def by_ownership(relation)
      case @params[:custom].to_s
      when "true"  then relation.custom
      when "false" then relation.catalog
      else relation
      end
    end

    # `_` and `%` are wildcards in LIKE. Escaping them keeps a literal search
    # for "bench_press" from matching "bench press".
    def sanitize_like(term)
      term.gsub(/[\\%_]/) { |char| "\\#{char}" }
    end
  end
end
