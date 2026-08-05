module Catalog
  module Providers
    # Failure modes when talking to a catalog provider.
    #
    # The split matters to Catalog::Sync: transient failures are worth
    # retrying, permanent ones are not, and retrying a quota failure only
    # burns more of the quota.
    #
    # Grouped under one module so the file defines a single constant, which is
    # what Zeitwerk expects.
    module Errors
      class Base < StandardError; end

      # Timeouts, connection resets, 5xx. Safe to retry with backoff.
      class Transient < Base; end

      # 401/403. The key is missing, wrong, or the plan does not include this
      # endpoint. Retrying cannot help and would waste requests.
      class Authentication < Base; end

      # 429, or a quota header showing nothing left. Retried briefly, then
      # abandoned: continuing makes the situation worse.
      class Quota < Base; end

      # The response arrived but did not look like what we expect —
      # unparseable JSON, or an envelope without the documented shape. Never
      # retried, because an identical request returns an identical answer.
      class Schema < Base; end
    end
  end
end
