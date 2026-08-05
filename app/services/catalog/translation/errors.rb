module Catalog
  module Translation
    # Failure modes for a translation provider.
    #
    # Grouped under one module so the file defines a single constant, matching
    # Catalog::Providers::Errors.
    module Errors
      class Base < StandardError; end

      # No provider is configured. Not really a failure: it means Italian is
      # simply not being generated yet, and callers should skip rather than
      # crash a sync.
      class NotConfigured < Base; end

      # Timeouts and 5xx. Worth retrying.
      class Transient < Base; end

      # Bad or missing credentials, or a quota/billing refusal. Retrying costs
      # money or makes the situation worse.
      class Rejected < Base; end

      # The response arrived but was not the documented shape.
      class Schema < Base; end
    end
  end
end
