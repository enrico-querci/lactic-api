# A coach's current billing state, synced from RevenueCat. At most one row
# per coach; a coach with no row is on the Free plan — nothing needs
# backfilling, and a lapsed subscription naturally reads as Free once
# expires_at passes, with no separate "canceled" bookkeeping.
class CreateCoachSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :coach_subscriptions do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }

      t.string :plan_key, null: false
      t.string :entitlement_id
      t.string :product_id
      t.string :store

      t.string :environment, null: false, default: "PRODUCTION"
      t.datetime :expires_at
      t.boolean :auto_renew, null: false, default: true
      t.datetime :billing_issue_at

      # Usually equals user_id, but stored explicitly so a TRANSFER/alias
      # event (see RevenueCat's restore-behavior settings) can be
      # reconciled against the App User ID RevenueCat actually reports.
      t.string :revenuecat_app_user_id

      t.datetime :synced_at

      t.timestamps
    end

    add_check_constraint :coach_subscriptions,
      "plan_key IN ('free', 'pro', 'pro_plus', 'unlimited', 'founding')",
      name: "coach_subscriptions_plan_key"

    add_check_constraint :coach_subscriptions,
      "environment IN ('PRODUCTION', 'SANDBOX')",
      name: "coach_subscriptions_environment"
  end
end
