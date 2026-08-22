module Billing
  # Failure modes for the RevenueCat client, mirroring
  # Catalog::Translation::Errors — grouped under one module so the file
  # defines a single constant.
  module Errors
    class Base < StandardError; end

    # No secret key/project id configured. Not a failure: billing is simply
    # not wired up yet, and callers should treat the coach as Free rather
    # than crash.
    class NotConfigured < Base; end

    # Timeouts and 5xx. Worth retrying.
    class Transient < Base; end

    # Bad or missing credentials, or an unrecognized customer.
    class Rejected < Base; end

    # The response arrived but was not the documented shape.
    class Schema < Base; end
  end
end
