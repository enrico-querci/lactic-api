module Catalog
  module Translation
    # Builds an Italian description from the exercise's own taxonomy instead of
    # translating the English one.
    #
    # Stage 0 established that provider descriptions are not authored prose —
    # they are mechanically composed from difficulty, mechanic, force, target,
    # bodyPart, equipment and category. The English for exercise 0001 reads:
    #
    #   "3/4 Sit-up is a beginner single-joint isolation pushing exercise
    #    targeting the Abs in the Waist region. Performed using bodyweight, it
    #    falls under the strength category. Secondary muscles engaged include
    #    Hip Flexors and Lower Back."
    #
    # Paying a translation provider per character to translate 1,327 generated
    # sentences would be waste. Composing them from a glossary of a few dozen
    # terms costs nothing per exercise, and gives consistent terminology that a
    # general-purpose translator would not.
    #
    # Returns nil when there is not enough taxonomy to say anything useful,
    # which leaves the description absent rather than half-formed.
    class DescriptionBuilder
      def self.call(...) = new(...).call

      def initialize(exercise, name:)
        @exercise = exercise
        @name = name
      end

      def call
        return nil if primary_muscle.blank?

        [ opening, equipment_sentence, secondary_sentence ].compact.join(" ").presence
      end

      private

      attr_reader :exercise, :name

      def opening
        muscle = Glossary.muscle(primary_muscle.name)
        qualifiers = [
          Glossary.difficulty(exercise.difficulty),
          Glossary.mechanic(exercise.mechanic),
          Glossary.force(exercise.force)
        ].compact_blank.join(" ")

        sentence = "#{name} è un esercizio"
        sentence += " #{qualifiers}" if qualifiers.present?
        sentence += " che coinvolge #{muscle}"
        sentence += " nella zona #{Glossary.region(primary_muscle.region)}" if primary_muscle.region.present?
        "#{sentence}."
      end

      def equipment_sentence
        names = exercise.equipment.map { |item| Glossary.equipment(item.name) }
        category = Glossary.category(exercise.category)
        return nil if names.empty? && category.blank?

        if names.empty?
          "Appartiene alla categoria #{category}."
        elsif category.blank?
          "Si esegue con #{to_sentence(names)}."
        else
          "Si esegue con #{to_sentence(names)} e appartiene alla categoria #{category}."
        end
      end

      def secondary_sentence
        names = exercise.secondary_muscles.map { |muscle| Glossary.muscle(muscle.name) }
        return nil if names.empty?

        "I muscoli secondari coinvolti sono #{to_sentence(names)}."
      end

      def primary_muscle = @primary_muscle ||= exercise.primary_muscle

      # Italian uses "e" where English uses "and"; the Rails default would
      # produce "Glutei, and Ischiocrurali".
      def to_sentence(items)
        items.to_sentence(two_words_connector: " e ", last_word_connector: " e ")
      end
    end
  end
end
