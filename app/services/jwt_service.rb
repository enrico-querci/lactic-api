class JwtService
  ALGORITHM = "HS256"
  ACCESS_TOKEN_EXPIRY = 15.minutes
  REFRESH_TOKEN_EXPIRY = 30.days

  class << self
    def encode(user_id:, expires_in: ACCESS_TOKEN_EXPIRY)
      payload = {
        user_id: user_id,
        exp: expires_in.from_now.to_i
      }
      JWT.encode(payload, secret_key, ALGORITHM)
    end

    def decode(token)
      decoded = JWT.decode(token, secret_key, true, algorithm: ALGORITHM)
      decoded.first
    end

    private

    def secret_key
      Rails.application.credentials.jwt_secret_key || ENV.fetch("JWT_SECRET_KEY") {
        raise "JWT secret key not configured. Run `bin/rails credentials:edit` and add jwt_secret_key."
      }
    end
  end
end
