require "test_helper"

class Api::V1::Coach::ClientInvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @client = users(:client_alice)
    ActionMailer::Base.deliveries.clear
  end

  test "index returns pending invitations for the coach" do
    invitation = ClientInvitation.create!(coach: @coach, email: "pending@example.com")
    ClientInvitation.create!(coach: @coach, email: "accepted@example.com", accepted_at: Time.current)

    get "/api/v1/coach/client_invitations", headers: auth_headers_for(@coach)

    assert_response :ok
    assert_equal [ invitation.id ], response.parsed_body.map { |item| item["id"] }
  end

  test "create saves and sends an invitation" do
    assert_difference [ "ClientInvitation.count", "ActionMailer::Base.deliveries.count" ], 1 do
      post "/api/v1/coach/client_invitations",
        params: { email: "New.Client@example.com" },
        headers: auth_headers_for(@coach)
    end

    assert_response :created
    invitation = ClientInvitation.order(:created_at).last
    assert_equal "new.client@example.com", invitation.email
    assert invitation.sent_at.present?
    assert_includes ActionMailer::Base.deliveries.last.body.encoded, "/invite/"
  end

  test "create renews an existing pending invitation" do
    invitation = ClientInvitation.create!(coach: @coach, email: "again@example.com")
    old_digest = invitation.token_digest

    assert_no_difference "ClientInvitation.count" do
      post "/api/v1/coach/client_invitations",
        params: { email: invitation.email },
        headers: auth_headers_for(@coach)
    end

    assert_response :created
    assert_not_equal old_digest, invitation.reload.token_digest
  end

  test "create rejects an existing client" do
    post "/api/v1/coach/client_invitations",
      params: { email: @client.email },
      headers: auth_headers_for(@coach)

    assert_response :unprocessable_entity
    assert_equal "This person is already your client", response.parsed_body["error"]
  end

  test "resend rotates the invitation token" do
    invitation = ClientInvitation.create!(coach: @coach, email: "resend@example.com")
    old_digest = invitation.token_digest

    post "/api/v1/coach/client_invitations/#{invitation.id}/resend", headers: auth_headers_for(@coach)

    assert_response :ok
    assert_not_equal old_digest, invitation.reload.token_digest
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  test "destroy revokes an invitation" do
    invitation = ClientInvitation.create!(coach: @coach, email: "revoke@example.com")

    delete "/api/v1/coach/client_invitations/#{invitation.id}", headers: auth_headers_for(@coach)

    assert_response :no_content
    assert invitation.reload.revoked_at.present?
  end

  test "client role cannot manage invitations" do
    get "/api/v1/coach/client_invitations", headers: auth_headers_for(@client)

    assert_response :forbidden
  end
end
