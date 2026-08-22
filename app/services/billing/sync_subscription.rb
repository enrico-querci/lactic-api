module Billing
  # The single authority for a coach's stored billing state. Always fetches
  # fresh from RevenueCat rather than trusting webhook payload contents —
  # webhook delivery is at-least-once with no ordering guarantee, so the
  # payload is only ever a signal to re-sync, never the source of truth.
  class SyncSubscription
    class UnknownUser < StandardError; end

    # App User IDs are always this app's own User#id (see
    # lib/billing/revenuecat.ts on the frontend) — anonymous RevenueCat IDs
    # are never used, so a lookup miss means something unexpected, not a
    # normal case to shrug off.
    def self.call(app_user_id:, client: RevenueCat::Client.new)
      user = User.find_by(id: app_user_id)
      raise UnknownUser, "no user for app_user_id=#{app_user_id}" unless user

      candidates = client.entitlements(app_user_id).filter_map do |entitlement|
        next unless entitlement[:gives_access]

        plan = Plans.for_entitlement(entitlement[:entitlement_id])
        next unless plan

        plan.merge(entitlement_id: entitlement[:entitlement_id], expires_at: entitlement[:expires_at])
      end

      chosen = candidates.find { |c| c[:client_limit].nil? } || candidates.max_by { |c| c[:client_limit] }

      subscription = user.coach_subscription || user.build_coach_subscription
      subscription.assign_attributes(
        plan_key: chosen ? chosen[:plan_key] : Plans::FREE_PLAN_KEY,
        entitlement_id: chosen&.fetch(:entitlement_id),
        expires_at: chosen ? parse_expiry(chosen[:expires_at]) : nil,
        environment: Rails.env.production? ? "PRODUCTION" : "SANDBOX",
        revenuecat_app_user_id: app_user_id,
        synced_at: Time.current
      )
      subscription.save!
      subscription
    end

    # Present-but-unparseable is treated as a hard failure (raises), not as
    # "no expiry" — silently granting permanent access on a parse error
    # would be the wrong failure mode. A genuinely absent value (nil,
    # meaning a lifetime/promotional grant) is the only path to nil.
    def self.parse_expiry(value)
      return nil if value.nil?
      return Time.zone.at(value.to_f / 1000) if value.is_a?(Numeric)

      # Time.zone.parse returns nil (not a raise) for a string it can't
      # parse at all — that must not fall through to the nil-means-no-
      # expiry case above, or garbage input would silently grant lifetime
      # access.
      Time.zone.parse(value.to_s) || (raise Errors::Schema, "unparseable expires_at: #{value.inspect}")
    rescue ArgumentError, TypeError
      raise Errors::Schema, "unparseable expires_at: #{value.inspect}"
    end
    private_class_method :parse_expiry
  end
end
