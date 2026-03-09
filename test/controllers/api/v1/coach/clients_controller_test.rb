require "test_helper"

class Api::V1::Coach::ClientsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @client = users(:client_alice)
    @client_bob = users(:client_bob)
  end

  # GET /api/v1/coach/clients
  test "index returns coach's clients" do
    get "/api/v1/coach/clients", headers: auth_headers_for(@coach)
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 2, json.size
    emails = json.map { |c| c["email"] }
    assert_includes emails, @client.email
    assert_includes emails, @client_bob.email
  end

  test "index returns 401 without token" do
    get "/api/v1/coach/clients"
    assert_response :unauthorized
  end

  test "index returns 403 for client role" do
    get "/api/v1/coach/clients", headers: auth_headers_for(@client)
    assert_response :forbidden
  end

  # GET /api/v1/coach/clients/:id
  test "show returns a specific client" do
    get "/api/v1/coach/clients/#{@client.id}", headers: auth_headers_for(@coach)
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal @client.email, json["email"]
  end

  test "show returns 404 for non-owned client" do
    other_client = User.create!(name: "Other", email: "other@example.com", role: "client")
    get "/api/v1/coach/clients/#{other_client.id}", headers: auth_headers_for(@coach)
    assert_response :not_found
  end

  # DELETE /api/v1/coach/clients/:id
  test "destroy removes client from coach" do
    delete "/api/v1/coach/clients/#{@client_bob.id}", headers: auth_headers_for(@coach)
    assert_response :no_content
    assert_nil @client_bob.reload.coach_id
  end

  test "destroy returns 404 for non-owned client" do
    other_client = User.create!(name: "Other2", email: "other2@example.com", role: "client")
    delete "/api/v1/coach/clients/#{other_client.id}", headers: auth_headers_for(@coach)
    assert_response :not_found
  end
end
