# Idempotency ledger and audit trail for inbound RevenueCat webhooks.
# RevenueCat delivery is at-least-once with no ordering guarantee (a failed
# delivery can retry up to 80 minutes later, arriving after newer events),
# so event_id is the only thing safe to dedupe on — never arrival order.
class CreateRevenueCatWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :revenue_cat_webhook_events do |t|
      t.string :event_id, null: false
      t.string :event_type, null: false
      t.string :app_user_id
      t.string :environment
      t.jsonb :payload, null: false, default: {}
      t.datetime :processed_at

      t.timestamps
    end

    add_index :revenue_cat_webhook_events, :event_id, unique: true
  end
end
