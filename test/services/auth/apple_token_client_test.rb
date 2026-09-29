require "test_helper"

class Auth::AppleTokenClientTest < ActiveSupport::TestCase
  # Same FakeHttp shape as Billing::RevenueCat::ClientTest.
  FakeResponse = Data.define(:code, :body)

  class FakeHttp
    attr_reader :requests

    def initialize(response)
      @response = response
      @requests = []
    end

    def request(uri, request)
      @requests << { uri: uri, form: URI.decode_www_form(request.body).to_h }
      @response
    end
  end

  SIGNING_KEY = OpenSSL::PKey::EC.generate("prime256v1")

  def build(response, private_key: SIGNING_KEY.to_pem)
    http = FakeHttp.new(response)
    client = Auth::AppleTokenClient.new(team_id: "TEAM123456", key_id: "KEY1234567", private_key: private_key, http: http)
    [ client, http ]
  end

  test "exchanges an authorization code for the refresh token" do
    client, http = build(FakeResponse.new(code: "200", body: { refresh_token: "r-1", access_token: "a-1" }.to_json))

    assert_equal "r-1", client.exchange(code: "code-1", client_id: "com.enricoquerci.lactic")

    request = http.requests.first
    assert_equal "https://appleid.apple.com/auth/token", request[:uri].to_s
    assert_equal "authorization_code", request[:form]["grant_type"]
    assert_equal "code-1", request[:form]["code"]
    assert_equal "com.enricoquerci.lactic", request[:form]["client_id"]
  end

  # Apple rejects the whole request unless the secret is an ES256 JWT from
  # this team, for this client, with the key's id in the header.
  test "signs the client secret as Apple requires" do
    client, http = build(FakeResponse.new(code: "200", body: { refresh_token: "r-1" }.to_json))
    client.exchange(code: "code-1", client_id: "com.enricoquerci.lacticstudio")

    secret = http.requests.first[:form]["client_secret"]
    claims, header = JWT.decode(secret, SIGNING_KEY, true, algorithm: "ES256")

    assert_equal "KEY1234567", header["kid"]
    assert_equal "TEAM123456", claims["iss"]
    assert_equal "com.enricoquerci.lacticstudio", claims["sub"]
    assert_equal "https://appleid.apple.com", claims["aud"]
    assert claims["exp"] > Time.current.to_i
  end

  test "accepts a private key pasted with escaped newlines" do
    escaped = SIGNING_KEY.to_pem.gsub("\n", "\\n")
    client, = build(FakeResponse.new(code: "200", body: { refresh_token: "r-1" }.to_json), private_key: escaped)

    assert_equal "r-1", client.exchange(code: "code-1", client_id: "com.enricoquerci.lactic")
  end

  test "revokes a refresh token" do
    client, http = build(FakeResponse.new(code: "200", body: ""))

    assert client.revoke(refresh_token: "r-1", client_id: "com.enricoquerci.lactic")

    request = http.requests.first
    assert_equal "https://appleid.apple.com/auth/revoke", request[:uri].to_s
    assert_equal "r-1", request[:form]["token"]
    assert_equal "refresh_token", request[:form]["token_type_hint"]
  end

  test "reports Apple's error code without echoing the response" do
    client, = build(FakeResponse.new(code: "400", body: { error: "invalid_grant", error_description: "detail" }.to_json))

    error = assert_raises(Auth::AppleTokenClient::Error) do
      client.exchange(code: "used", client_id: "com.enricoquerci.lactic")
    end
    assert_match "invalid_grant", error.message
    assert_no_match "detail", error.message
  end

  test "is unconfigured without all three variables and never calls out" do
    http = FakeHttp.new(FakeResponse.new(code: "200", body: "{}"))
    client = Auth::AppleTokenClient.new(team_id: "TEAM123456", key_id: "", private_key: "pem", http: http)

    assert_not client.configured?
    assert_raises(Auth::AppleTokenClient::Error) { client.revoke(refresh_token: "r", client_id: "c") }
    assert_empty http.requests
  end

  test "never exposes the key through inspect" do
    client, = build(FakeResponse.new(code: "200", body: "{}"))

    assert_no_match "PRIVATE", client.inspect
  end
end
