require "test_helper"

class Api::V1::Coach::ClientProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @client = users(:client_alice)
    @prepared = client_profiles(:carla_prepared)
    @active = client_profiles(:alice_profile)
  end

  def url(suffix = "")
    "/api/v1/coach/client_profiles#{suffix}"
  end

  def json
    JSON.parse(response.body)
  end

  def invite(email)
    ClientInvitation.create!(coach: @coach, email: email)
  end

  # GET index
  test "index lists the coach's profiles by name with their status" do
    invite("bob@example.com") # already a client: still active
    get url, headers: auth_headers_for(@coach)

    assert_response :ok
    assert_equal [ "Alice Client", "Bob Client", "Carla Prepared" ], json.map { |p| p["name"] }
    assert_equal %w[active active prepared], json.map { |p| p["status"] }
  end

  test "a pending invitation makes the profile invited" do
    invitation = invite("carla@example.com")
    get url, headers: auth_headers_for(@coach)

    carla = json.find { |p| p["email"] == "carla@example.com" }
    assert_equal "invited", carla["status"]
    assert_equal invitation.id, carla["invitation_id"]
    assert carla["invitation_expires_at"].present?
  end

  test "an expired or revoked invitation leaves the profile prepared" do
    invite("carla@example.com").update!(expires_at: 1.day.ago)
    get url("/#{@prepared.id}"), headers: auth_headers_for(@coach)
    assert_equal "prepared", json["status"]
    assert_nil json["invitation_id"]

    ClientInvitation.where(email: "carla@example.com").delete_all
    invite("carla@example.com").revoke!
    get url("/#{@prepared.id}"), headers: auth_headers_for(@coach)
    assert_equal "prepared", json["status"]
  end

  test "index does not leak another coach's profiles" do
    other = User.create!(name: "Other Coach", email: "other-coach-list@example.com", role: :coach)
    other.client_profiles.create!(name: "Secret Client")
    get url, headers: auth_headers_for(@coach)
    assert_not_includes json.map { |p| p["name"] }, "Secret Client"
  end

  test "index returns 403 for a client" do
    get url, headers: auth_headers_for(@client)
    assert_response :forbidden
  end

  # GET show
  test "show returns every field" do
    get url("/#{@prepared.id}"), headers: auth_headers_for(@coach)
    assert_response :ok
    assert_equal "Left knee, no deep squats", json["limitations"]
    assert_equal "+39 333 1234567", json["phone"]
    assert_equal "prepared", json["status"]
    assert_nil json["user_id"]
  end

  test "show returns 404 for another coach's profile" do
    other = User.create!(name: "Other Coach", email: "other-coach-show@example.com", role: :coach)
    profile = other.client_profiles.create!(name: "Not yours")
    get url("/#{profile.id}"), headers: auth_headers_for(@coach)
    assert_response :not_found
  end

  # POST create
  test "create needs only a name" do
    assert_difference "ClientProfile.count", 1 do
      post url, params: { name: "Dana" }, headers: auth_headers_for(@coach), as: :json
    end
    assert_response :created
    assert_equal "prepared", json["status"]
    assert_equal @coach.id, ClientProfile.find(json["id"]).coach_id
  end

  test "create keeps every field" do
    post url, params: { name: "Dana", email: "Dana@Example.com", phone: "123", level: "beginner",
                        goal: "strength", limitations: "bad back", notes: "prefers mornings" },
         headers: auth_headers_for(@coach), as: :json
    assert_response :created
    assert_equal [ "dana@example.com", "123", "beginner", "strength", "bad back", "prefers mornings" ],
                 json.values_at("email", "phone", "level", "goal", "limitations", "notes")
  end

  test "create ignores attempts to set the owner or the linked user" do
    other = User.create!(name: "Other Coach", email: "other-coach-create@example.com", role: :coach)
    post url, params: { name: "Dana", coach_id: other.id, user_id: @client.id }, headers: auth_headers_for(@coach), as: :json
    assert_response :created
    profile = ClientProfile.find(json["id"])
    assert_equal [ @coach.id, nil ], [ profile.coach_id, profile.user_id ]
  end

  test "create rejects a missing name, a bad email and unknown values" do
    [ { name: "" }, { name: "Dana", email: "nope" }, { name: "Dana", level: "expert" } ].each do |params|
      assert_no_difference "ClientProfile.count" do
        post url, params: params, headers: auth_headers_for(@coach), as: :json
      end
      assert_response :unprocessable_entity
    end
  end

  test "create rejects an email the coach already has" do
    assert_no_difference "ClientProfile.count" do
      post url, params: { name: "Dup", email: "ALICE@example.com" }, headers: auth_headers_for(@coach), as: :json
    end
    assert_response :unprocessable_entity
  end

  test "create returns 403 for a client" do
    post url, params: { name: "Dana" }, headers: auth_headers_for(@client), as: :json
    assert_response :forbidden
  end

  # PATCH update
  test "update changes only what is sent" do
    patch url("/#{@prepared.id}"), params: { phone: "999", goal: "health" },
          headers: auth_headers_for(@coach), as: :json
    assert_response :ok
    @prepared.reload
    assert_equal [ "999", "health", "Carla Prepared", "carla@example.com" ],
                 [ @prepared.phone, @prepared.goal, @prepared.name, @prepared.email ]
  end

  test "update can clear an optional field" do
    patch url("/#{@prepared.id}"), params: { limitations: "" }, headers: auth_headers_for(@coach), as: :json
    assert_response :ok
    assert_nil @prepared.reload.limitations
  end

  test "update rejects a blank name" do
    patch url("/#{@prepared.id}"), params: { name: "" }, headers: auth_headers_for(@coach), as: :json
    assert_response :unprocessable_entity
    assert_equal "Carla Prepared", @prepared.reload.name
  end

  test "the email can change while the person has not been invited" do
    patch url("/#{@prepared.id}"), params: { email: "carla.new@example.com" }, headers: auth_headers_for(@coach), as: :json
    assert_response :ok
    assert_equal "carla.new@example.com", @prepared.reload.email
  end

  test "the email is fixed once an invitation is pending" do
    invite("carla@example.com")
    patch url("/#{@prepared.id}"), params: { email: "other@example.com", phone: "1" },
          headers: auth_headers_for(@coach), as: :json
    assert_response :unprocessable_entity
    assert_equal "carla@example.com", @prepared.reload.email
    assert_equal "+39 333 1234567", @prepared.phone
  end

  test "the email is fixed once the person has joined, but resending it is fine" do
    patch url("/#{@active.id}"), params: { email: "new@example.com" }, headers: auth_headers_for(@coach), as: :json
    assert_response :unprocessable_entity

    patch url("/#{@active.id}"), params: { email: "alice@example.com", notes: "ok" },
          headers: auth_headers_for(@coach), as: :json
    assert_response :ok
    assert_equal "ok", @active.reload.notes
  end

  test "update returns 404 for another coach's profile" do
    other = User.create!(name: "Other Coach", email: "other-coach-update@example.com", role: :coach)
    profile = other.client_profiles.create!(name: "Not yours")
    patch url("/#{profile.id}"), params: { name: "Mine now" }, headers: auth_headers_for(@coach), as: :json
    assert_response :not_found
    assert_equal "Not yours", profile.reload.name
  end

  # DELETE destroy
  test "destroy deletes a prepared profile" do
    assert_difference "ClientProfile.count", -1 do
      delete url("/#{@prepared.id}"), headers: auth_headers_for(@coach)
    end
    assert_response :no_content
  end

  test "destroying an invited profile also revokes its invitation" do
    invitation = invite("carla@example.com")
    assert_difference "ClientProfile.count", -1 do
      delete url("/#{@prepared.id}"), headers: auth_headers_for(@coach)
    end
    assert_equal "revoked", invitation.reload.status
  end

  test "destroy refuses a profile whose person has joined" do
    assert_no_difference "ClientProfile.count" do
      delete url("/#{@active.id}"), headers: auth_headers_for(@coach)
    end
    assert_response :conflict
    assert_equal "client_active", json["code"]
  end

  test "destroy returns 403 for a client" do
    delete url("/#{@prepared.id}"), headers: auth_headers_for(@client)
    assert_response :forbidden
  end
end
