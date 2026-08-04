require "test_helper"

class Api::V1::ClientInvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @client = User.create!(name: "Invitee", email: "invitee@example.com", role: :client)
    @invitation = ClientInvitation.create!(coach: @coach, email: @client.email)
    @token = @invitation.raw_token
  end

  test "show exposes valid invitation details without authentication" do
    get "/api/v1/client_invitations/#{@token}"

    assert_response :ok
    assert_equal @invitation.email, response.parsed_body["email"]
    assert_equal @coach.name, response.parsed_body["coach_name"]
    assert_equal "pending", response.parsed_body["status"]
  end

  test "show returns not found for an invalid token" do
    get "/api/v1/client_invitations/invalid"

    assert_response :not_found
  end

  test "accept links the authenticated client" do
    post "/api/v1/client_invitations/#{@token}/accept", headers: auth_headers_for(@client)

    assert_response :ok
    assert_equal @coach, @client.reload.coach
    assert @invitation.reload.accepted_at.present?
  end

  test "accept requires authentication" do
    post "/api/v1/client_invitations/#{@token}/accept"

    assert_response :unauthorized
  end

  test "accept rejects the wrong email" do
    post "/api/v1/client_invitations/#{@token}/accept", headers: auth_headers_for(users(:client_bob))

    assert_response :unprocessable_entity
    assert_match @invitation.email, response.parsed_body["error"]
  end
end
