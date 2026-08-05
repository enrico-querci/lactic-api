module Catalog
  # Turns one raw provider exercise into Lactic's own shape.
  #
  # This is the boundary the plan requires: nothing outside `Catalog::` should
  # know that the provider calls a muscle `target`, an animation `gifUrl`, or a
  # body region `bodyPart`.
  #
  # It is a PURE transformation. It emits taxonomy *keys*, never database ids,
  # and touches no tables, so it can be tested against the checked-in fixture
  # without a database. `Catalog::Sync` resolves keys to records and persists.
  #
  # Malformed input is reported rather than raised: `result.valid?` is false and
  # `result.errors` explains why, so the caller can quarantine the row and carry
  # on instead of failing a whole page.
  class NormalizeExercise
    # v1 prescribes repetitions only. The provider catalog also contains cardio,
    # balance and flexibility work (about 14% of a 140-record sample), which
    # reps cannot express, so those import but are not offered in the picker.
    ASSIGNABLE_CATEGORIES = %w[strength].freeze

    REQUIRED_FIELDS = %w[id name target gifUrl].freeze

    Muscle = Data.define(:key, :name, :region)
    Equipment = Data.define(:key, :name)
    Animation = Data.define(:provider_url, :provider_media_uid, :mime_type)

    Result = Data.define(
      :source_uid, :name, :description, :instructions,
      :category, :difficulty, :mechanic, :force,
      :primary_muscle, :secondary_muscles, :equipment, :animation,
      :content_checksum, :assignable, :errors
    ) do
      def valid? = errors.empty?
      def assignable? = assignable
    end

    def self.call(raw) = new(raw).call

    def initialize(raw)
      @raw = raw.is_a?(Hash) ? raw : {}
      @errors = []
    end

    def call
      validate_required_fields

      primary = build_primary_muscle
      name = squish(@raw["name"])

      Result.new(
        source_uid: squish(@raw["id"]),
        name: name,
        description: squish(@raw["description"]).presence,
        instructions: build_instructions,
        category: downcase_token(@raw["category"]),
        difficulty: downcase_token(@raw["difficulty"]),
        mechanic: downcase_token(@raw["mechanic"]),
        force: downcase_token(@raw["force"]),
        primary_muscle: primary,
        secondary_muscles: build_secondary_muscles(primary),
        equipment: build_equipment,
        animation: build_animation,
        content_checksum: checksum_for(name),
        assignable: ASSIGNABLE_CATEGORIES.include?(downcase_token(@raw["category"])),
        errors: @errors.freeze
      )
    end

    # Stable key for a taxonomy value: "Ez Barbell" -> "ez_barbell".
    # A trailing parenthetical qualifier is dropped, so
    # "Dumbbell (used As Handles For Deeper Range)" collapses onto "dumbbell".
    def self.taxonomy_key(value)
      base = value.to_s.gsub(/\(.*?\)/, " ")
      base.strip.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "").presence
    end

    # Display name matching the key: the provider's own wording, minus the
    # qualifier and with whitespace tidied.
    def self.taxonomy_name(value)
      value.to_s.gsub(/\(.*?\)/, " ").squish.presence
    end

    private

    def validate_required_fields
      REQUIRED_FIELDS.each do |field|
        @errors << "missing #{field}" if blank_value?(@raw[field])
      end
    end

    def blank_value?(value)
      value.nil? || (value.respond_to?(:empty?) && value.empty?) || value.to_s.strip.empty?
    end

    def build_primary_muscle
      key = self.class.taxonomy_key(@raw["target"])
      if key.nil?
        # `target` was present but held nothing usable, e.g. "()" or "--".
        # Without a primary muscle an exercise cannot be counted in volume
        # metrics, so reject it rather than let Sync link nothing.
        @errors << "unusable target" unless blank_value?(@raw["target"])
        return nil
      end

      Muscle.new(
        key: key,
        name: self.class.taxonomy_name(@raw["target"]),
        # Only the primary muscle carries a region: `bodyPart` describes the
        # exercise's target, and secondary muscles have no equivalent field.
        region: squish(@raw["bodyPart"]).presence
      )
    end

    # Secondary muscles are an OPEN vocabulary — the live data contains values
    # such as "Hip Flexors" that never appear in the provider's targetList — so
    # they are passed through with a null region for Sync to create on demand.
    # The primary muscle is excluded to avoid an exercise linking the same
    # muscle twice, which the join table forbids.
    def build_secondary_muscles(primary)
      Array(@raw["secondaryMuscles"])
        .filter_map do |value|
          key = self.class.taxonomy_key(value)
          next if key.nil? || key == primary&.key

          Muscle.new(key: key, name: self.class.taxonomy_name(value), region: nil)
        end
        .uniq(&:key)
    end

    # The provider packs several items into one string: "Dumbbell, Exercise
    # Ball, Tennis Ball" is three pieces of equipment, not one.
    def build_equipment
      @raw["equipment"].to_s
        .split(",")
        .filter_map do |part|
          key = self.class.taxonomy_key(part)
          next if key.nil?

          Equipment.new(key: key, name: self.class.taxonomy_name(part))
        end
        .uniq(&:key)
    end

    def build_animation
      url = squish(@raw["gifUrl"]).presence
      return nil if url.nil?

      Animation.new(
        provider_url: url,
        provider_media_uid: File.basename(URI(url).path, ".*").presence,
        mime_type: "image/gif"
      )
    rescue URI::InvalidURIError
      @errors << "malformed gifUrl"
      nil
    end

    def build_instructions
      steps = Array(@raw["instructions"]).filter_map { |step| squish(step).presence }
      @errors << "missing instructions" if steps.empty?
      steps
    end

    # Deterministic checksum over exactly the English content that Stage 3
    # translates. Taxonomy is excluded on purpose: a provider retagging an
    # exercise's equipment must not invalidate a good Italian translation.
    def checksum_for(name)
      payload = {
        name: name,
        description: squish(@raw["description"]),
        instructions: Array(@raw["instructions"]).map { |step| squish(step) }
      }
      Digest::SHA256.hexdigest(JSON.generate(payload))
    end

    def squish(value) = value.to_s.squish

    def downcase_token(value)
      squish(value).downcase.presence
    end
  end
end
