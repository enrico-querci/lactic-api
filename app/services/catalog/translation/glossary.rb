module Catalog
  module Translation
    # Canonical Italian terms for the catalog's taxonomy.
    #
    # Loaded once and memoized: this is read on every exercise a translation
    # run touches, and re-reading the file 1,300 times would be the slowest
    # part of an otherwise network-bound job.
    #
    # Every lookup falls back to the English term rather than guessing. A
    # missing entry then shows up as an English word in Italian copy, which is
    # obvious and fixable, instead of silently becoming something wrong.
    class Glossary
      PATH = Rails.root.join("config/catalog_glossary.yml")

      class << self
        def instance
          @instance ||= new
        end

        # Only for tests, which need a glossary built from a different file.
        def reset! = @instance = nil

        delegate :muscle, :region, :equipment, :category, :difficulty,
          :mechanic, :force, :covers_muscle?, :covers_equipment?, to: :instance
      end

      def initialize(path: PATH)
        @data = YAML.safe_load_file(path) || {}
      end

      def muscle(term) = lookup("muscles", term)
      def region(term) = lookup("regions", term)
      def equipment(term) = lookup("equipment", term)
      def category(term) = lookup("categories", term, downcase: true)
      def difficulty(term) = lookup("difficulties", term, downcase: true)
      def mechanic(term) = lookup("mechanics", term, downcase: true)
      def force(term) = lookup("forces", term, downcase: true)

      # Coverage is key presence, not "the Italian differs from the English".
      # Several terms are loanwords — Kettlebell, Core, Stretching — and are
      # correctly identical in both languages.
      def covers_muscle?(term) = section("muscles").key?(term.to_s)
      def covers_equipment?(term) = section("equipment").key?(term.to_s)

      private

      def lookup(section_name, term, downcase: false)
        return nil if term.blank?

        key = downcase ? term.to_s.downcase : term.to_s
        section(section_name).fetch(key, term.to_s)
      end

      def section(name) = @data.fetch(name, {})
    end
  end
end
