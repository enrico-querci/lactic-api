# A coach's current billing state, synced from RevenueCat. Never trust a
# stored "canceled"/"active" flag here — active? is derived from expires_at
# so a missed webhook self-heals: access lapses on its own once the period
# ends rather than staying granted forever.
class CoachSubscription < ApplicationRecord
  belongs_to :user

  validates :plan_key, presence: true, inclusion: { in: Billing::Plans::PLAN_KEYS }
  validates :environment, presence: true, inclusion: { in: %w[PRODUCTION SANDBOX] }

  def active?
    plan_key != Billing::Plans::FREE_PLAN_KEY && (expires_at.nil? || expires_at.future?)
  end

  def client_limit
    return Billing::Plans::FREE_CLIENT_LIMIT unless active?

    Billing::Plans::ENTITLEMENTS.values.find { |e| e[:plan_key] == plan_key }&.fetch(:client_limit, nil)
  end
end
