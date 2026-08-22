module Billing
  # The one place Lactic Studio's paid tiers are defined. A RevenueCat
  # entitlement identifier maps to a plan key and a client limit; nil means
  # unlimited. If a coach somehow holds more than one active entitlement,
  # Billing::SyncSubscription picks whichever has the highest client_limit
  # (unlimited, i.e. nil, beats any number).
  module Plans
    FREE_PLAN_KEY = "free"
    FREE_CLIENT_LIMIT = 3

    PLAN_KEYS = %w[free pro pro_plus unlimited founding].freeze

    # entitlement_id => { plan_key:, client_limit: }
    ENTITLEMENTS = {
      "studio_founding"  => { plan_key: "founding",  client_limit: nil },
      "studio_unlimited" => { plan_key: "unlimited", client_limit: nil },
      "studio_pro_plus"  => { plan_key: "pro_plus",  client_limit: 50 },
      "studio_pro"       => { plan_key: "pro",       client_limit: 15 }
    }.freeze

    def self.for_entitlement(entitlement_id)
      ENTITLEMENTS[entitlement_id]
    end
  end
end
