module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate!
  end

  private

  def authenticate!
    token = extract_token_from_header
    payload = JwtService.decode(token)
    @current_user = User.find(payload["user_id"])
    # id + role only — never email or name. Attached as soon as identity is
    # known, since AuthController bypasses ErrorHandling (it inherits
    # ApplicationController directly) and this is the one place both it and
    # every other controller pass through. A no-op when Sentry was never
    # initialized (no SENTRY_DSN, e.g. in test/dev).
    Sentry.set_user(id: @current_user.id, role: @current_user.role)
  rescue JWT::ExpiredSignature
    # Normal traffic — every access token expires. Not worth reporting.
    render json: { error: "Unauthorized" }, status: :unauthorized
  rescue JWT::DecodeError, ActiveRecord::RecordNotFound => e
    # A malformed token or one naming a deleted user is not routine: it is
    # either an attack, a bug in token issuance, or a dangling reference.
    Sentry.capture_exception(e)
    render json: { error: "Unauthorized" }, status: :unauthorized
  end

  def current_user
    @current_user
  end

  def extract_token_from_header
    header = request.headers["Authorization"]
    header&.split(" ")&.last
  end
end
