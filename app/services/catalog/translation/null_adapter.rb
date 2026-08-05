module Catalog
  module Translation
    # The adapter used when no translation provider is configured.
    #
    # Reports itself as unconfigured so a sync skips translation entirely and
    # carries on, rather than failing. Italian simply does not appear, and the
    # API's locale fallback already serves English in that case — which is the
    # behaviour every environment has today, since no provider credential
    # exists yet.
    class NullAdapter
      def configured? = false

      def name = "none"

      def translate(_texts, to:, from: "en")
        raise Errors::NotConfigured, "no translation provider is configured"
      end
    end
  end
end
