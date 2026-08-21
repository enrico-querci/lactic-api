module Catalog
  module Translation
    # Locale-aware display labels for coach/client-facing API responses.
    #
    # Glossary is Italian-by-construction with no locale parameter —
    # DescriptionBuilder calls it positionally, always composing Italian
    # prose. This wraps it for the places that serve either language: the
    # english path returns the input verbatim rather than routing through
    # Glossary's fallback-to-english branch, so untranslated output stays
    # byte-identical to what shipped before locale awareness existed.
    module TaxonomyLabels
      module_function

      def muscle(name, locale) = italian?(locale) ? Glossary.muscle(name) : name
      def equipment(name, locale) = italian?(locale) ? Glossary.equipment(name) : name

      # Sums rather than assigns: the catalog carries two English vocabularies
      # for the same muscle at once (hand-seeded seeds vs. the provider's
      # import — e.g. "Chest" and "Pectorals" both exist today), and both map
      # onto one Italian term. A transform_keys would silently drop whichever
      # side collided last; summing keeps every set counted under one badge.
      # #to_h sheds the Hash.new(0) default proc before serialization.
      def volume_sets(counts, locale)
        return counts unless italian?(locale)

        counts.each_with_object(Hash.new(0)) { |(name, sets), acc| acc[muscle(name, locale)] += sets }.to_h
      end

      def italian?(locale) = locale.to_s == "it"
    end
  end
end
