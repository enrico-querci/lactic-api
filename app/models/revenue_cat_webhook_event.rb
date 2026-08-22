# Idempotency ledger and audit trail for inbound RevenueCat webhooks. See
# db/migrate/20260822090100_create_revenue_cat_webhook_events.rb — delivery
# is at-least-once with no ordering guarantee, so event_id is the only safe
# dedupe key.
class RevenueCatWebhookEvent < ApplicationRecord
  validates :event_id, presence: true, uniqueness: true
  validates :event_type, presence: true

  def processed?
    processed_at.present?
  end
end
