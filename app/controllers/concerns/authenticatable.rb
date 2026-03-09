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
  rescue JWT::DecodeError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound
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
