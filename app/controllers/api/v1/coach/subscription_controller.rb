module Api
  module V1
    module Coach
      class SubscriptionController < BaseController
        # GET /api/v1/coach/subscription
        def show
          render json: subscription_json
        end

        # POST /api/v1/coach/subscription/sync
        #
        # Called by the web app right after checkout, so activation is
        # instant rather than waiting on webhook latency; also works as a
        # manual "refresh" escape hatch if a webhook was ever missed.
        def sync
          Billing::SyncSubscription.call(app_user_id: current_user.id.to_s)
          current_user.reload
          render json: subscription_json
        rescue Billing::Errors::NotConfigured
          render json: { error: "Billing is not configured" }, status: :service_unavailable
        rescue Billing::Errors::Transient, Billing::Errors::Rejected, Billing::Errors::Schema => e
          Sentry.capture_exception(e)
          render json: { error: "Could not refresh subscription status" }, status: :bad_gateway
        end

        private

        # Subscription *management* (cancel, change plan, update card)
        # happens client-side through the RevenueCat Web Billing SDK, which
        # is already authenticated as this specific customer — it is not
        # this endpoint's job to construct or proxy a management URL.
        def subscription_json
          sub = current_user.coach_subscription
          {
            plan: sub&.active? ? sub.plan_key : Billing::Plans::FREE_PLAN_KEY,
            client_limit: current_user.client_limit,
            client_slots_used: current_user.client_slots_used,
            expires_at: sub&.expires_at,
            auto_renew: sub&.auto_renew,
            billing_issue: sub&.billing_issue_at.present?
          }
        end
      end
    end
  end
end
