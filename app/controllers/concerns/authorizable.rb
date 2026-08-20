module Authorizable
  extend ActiveSupport::Concern

  private

  def require_coach!
    return if current_user&.coach?

    report_forbidden("coach")
    render json: { error: "Forbidden" }, status: :forbidden
  end

  def require_client!
    return if current_user&.client?

    report_forbidden("client")
    render json: { error: "Forbidden" }, status: :forbidden
  end

  # A client hitting a coach-only endpoint (or the reverse) never raises —
  # it renders 403 directly, so nothing here would otherwise reach Sentry.
  # A capture_message rather than an exception, since there is no error
  # object: the request is well-formed, just not permitted. User context
  # (id + role) is already attached by Authenticatable by the time this
  # runs, so no PII needs to travel with the message.
  def report_forbidden(required_role)
    Sentry.capture_message(
      "Forbidden: #{required_role} endpoint",
      level: "warning",
      tags: { path: request.path }
    )
  end
end
