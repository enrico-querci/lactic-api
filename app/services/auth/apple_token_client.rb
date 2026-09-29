require "net/http"
require "json"

module Auth
  # The two Sign in with Apple REST calls this app makes: exchanging a
  # sign-in's authorization code for a refresh token, and revoking that
  # token when the account is deleted. App Review guideline 5.1.1(v)
  # requires the revocation of any app that offers Sign in with Apple
  # alongside account deletion.
  #
  # Same seam shape as Billing::RevenueCat::Client: no HTTP gem, and a
  # DefaultTransport that tests replace.
  #
  # Optional, like Resend, Sentry and RevenueCat: without all three
  # variables #configured? is false and callers skip both calls. Sign-in
  # itself never depends on this — AppleVerifier needs only Apple's public
  # keys.
  class AppleTokenClient
    TOKEN_URL = "https://appleid.apple.com/auth/token".freeze
    REVOKE_URL = "https://appleid.apple.com/auth/revoke".freeze
    ISSUER = "https://appleid.apple.com".freeze

    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10

    class Error < StandardError; end

    # APPLE_SIGN_IN_PRIVATE_KEY is the .p8 file's PEM text. Railway keeps
    # real newlines, but a value pasted with literal "\n" works too.
    def initialize(team_id: ENV["APPLE_TEAM_ID"],
                    key_id: ENV["APPLE_SIGN_IN_KEY_ID"],
                    private_key: ENV["APPLE_SIGN_IN_PRIVATE_KEY"],
                    http: nil)
      @team_id = team_id.to_s.strip
      @key_id = key_id.to_s.strip
      @private_key = private_key.to_s.gsub("\\n", "\n").strip
      @http = http
    end

    def configured? = @team_id.present? && @key_id.present? && @private_key.present?

    # Never expose the key through inspection.
    def inspect = "#<#{self.class.name} configured=#{configured?}>"

    # Returns the refresh token. `client_id` must be the bundle ID the code
    # was issued to — the identity token's audience.
    def exchange(code:, client_id:)
      body = post(TOKEN_URL, client_id: client_id, code: code, grant_type: "authorization_code")
      body.fetch("refresh_token") { raise Error, "Apple returned no refresh token" }
    end

    def revoke(refresh_token:, client_id:)
      post(REVOKE_URL, client_id: client_id, token: refresh_token, token_type_hint: "refresh_token")
      true
    end

    private

    def post(url, client_id:, **params)
      raise Error, "APPLE_TEAM_ID/APPLE_SIGN_IN_KEY_ID/APPLE_SIGN_IN_PRIVATE_KEY not set" unless configured?

      uri = URI(url)
      request = Net::HTTP::Post.new(uri)
      request["Accept"] = "application/json"
      request.set_form_data(client_id: client_id, client_secret: client_secret(client_id), **params)

      response = transport.request(uri, request)
      interpret(response)
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, EOFError, SocketError => e
      raise Error, "network failure: #{e.class}"
    end

    # Apple's error bodies are {"error": "invalid_grant"} and the like.
    # Only that code is surfaced: the rest of a response is never echoed
    # into logs or error reports.
    def interpret(response)
      payload = response.body.present? ? JSON.parse(response.body) : {}
      return payload if response.code.to_i == 200

      raise Error, "Apple rejected the request (HTTP #{response.code}, #{payload["error"] || "no error code"})"
    rescue JSON::ParserError
      raise Error, "Apple returned unparseable JSON (HTTP #{response.code})"
    end

    # A short-lived ES256 JWT signed with the Sign in with Apple key, in
    # place of a static client secret. Apple accepts up to six months; five
    # minutes is plenty for one request.
    def client_secret(client_id)
      now = Time.current.to_i
      JWT.encode(
        { iss: @team_id, iat: now, exp: now + 300, aud: ISSUER, sub: client_id },
        OpenSSL::PKey::EC.new(@private_key),
        "ES256",
        { kid: @key_id }
      )
    end

    def transport
      @transport ||= @http || DefaultTransport.new
    end

    # Seam for tests. The real one is four lines.
    class DefaultTransport
      def request(uri, request)
        Net::HTTP.start(uri.host, uri.port, use_ssl: true,
          open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
          http.request(request)
        end
      end
    end
  end
end
