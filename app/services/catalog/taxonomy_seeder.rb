module Catalog
  # Seeds the reference muscle and equipment taxonomies from
  # db/catalog_taxonomy.yml.
  #
  # Idempotent and keyed on `key`, so it is safe to run on every deploy. It
  # never deletes: a muscle that disappears from the provider may still be
  # referenced by an existing exercise.
  #
  # It only fills in a blank region rather than overwriting one. Two seeded
  # regions are inferred rather than measured (see the YAML), and live data
  # should win over a guess.
  class TaxonomySeeder
    DEFAULT_PATH = Rails.root.join("db/catalog_taxonomy.yml")

    Report = Data.define(:muscles_created, :muscles_updated, :equipment_created, :equipment_updated) do
      def to_s
        "muscles: #{muscles_created} created, #{muscles_updated} updated; " \
          "equipment: #{equipment_created} created, #{equipment_updated} updated"
      end
    end

    def self.call(path: DEFAULT_PATH) = new(path: path).call

    def initialize(path: DEFAULT_PATH)
      @path = path
    end

    def call
      data = YAML.safe_load_file(@path, symbolize_names: false)
      muscles_created, muscles_updated = seed_muscles(data.fetch("muscles", []))
      equipment_created, equipment_updated = seed_equipment(data.fetch("equipment", []))

      Report.new(
        muscles_created: muscles_created,
        muscles_updated: muscles_updated,
        equipment_created: equipment_created,
        equipment_updated: equipment_updated
      )
    end

    private

    def seed_muscles(rows)
      created = 0
      updated = 0

      rows.each do |row|
        muscle = Muscle.find_or_initialize_by(key: row.fetch("key"))
        if muscle.new_record?
          muscle.assign_attributes(name: row.fetch("name"), region: row["region"])
          muscle.save!
          created += 1
        else
          muscle.name = row.fetch("name")
          muscle.region = row["region"] if muscle.region.blank?
          updated += 1 if muscle.changed?
          muscle.save!
        end
      end

      [ created, updated ]
    end

    def seed_equipment(rows)
      created = 0
      updated = 0

      rows.each do |row|
        item = Equipment.find_or_initialize_by(key: row.fetch("key"))
        if item.new_record?
          item.name = row.fetch("name")
          item.save!
          created += 1
        else
          item.name = row.fetch("name")
          updated += 1 if item.changed?
          item.save!
        end
      end

      [ created, updated ]
    end
  end
end
