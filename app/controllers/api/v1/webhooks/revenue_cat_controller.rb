module Api
  module V1
    module Webhooks
      # Inherits ApplicationController directly, not BaseController — same
      # reason as AuthController: it needs its own error contract (a bare
      # 200/401/400, no JWT), not ErrorHandling's rescues.
      class RevenueCatController < ApplicationController
        skip_before_action :authenticate!, only: :create

        # POST /api/v1/webhooks/revenuecat
        def create
          raw_body = request.raw_post
          authorized = Billing::RevenueCat::WebhookVerifier.valid?(
            raw_body: raw_body,
            signature_header: request.headers["X-RevenueCat-Webhook-Signature"],
            authorization_header: request.headers["Authorization"]
          )
          return head :unauthorized unless authorized

          event = parse_event(raw_body)
          return head :bad_request unless event

          record = RevenueCatWebhookEvent.find_or_initialize_by(event_id: event["id"])
          return head :ok if record.processed?

          record.assign_attributes(
            event_type: event["type"],
            app_user_id: event["app_user_id"],
            environment: event["environment"],
            payload: event
          )
          record.save!

          # Sandbox purchases hit this same production endpoint (and renew
          # every 5 minutes) — recorded for the audit trail, but never
          # applied to a real coach's entitlement.
          if Rails.env.production? && event["environment"] != "PRODUCTION"
            record.update!(processed_at: Time.current)
            return head :ok
          end

          begin
            Billing::SyncSubscription.call(app_user_id: event["app_user_id"])
          rescue Billing::SyncSubscription::UnknownUser => e
            # Retrying can't fix a user that doesn't exist. Record and move
            # on rather than let RevenueCat hammer this for 5 retries.
            Sentry.capture_exception(e)
          end

          record.update!(processed_at: Time.current)
          head :ok
        end

        private

        def parse_event(raw_body)
          JSON.parse(raw_body).fetch("event", nil)
        rescue JSON::ParserError
          nil
        end
      end
    end
  end
end
