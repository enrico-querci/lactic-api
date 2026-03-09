module Authorizable
  extend ActiveSupport::Concern

  private

  def require_coach!
    render json: { error: "Forbidden" }, status: :forbidden unless current_user&.coach?
  end

  def require_client!
    render json: { error: "Forbidden" }, status: :forbidden unless current_user&.client?
  end
end
