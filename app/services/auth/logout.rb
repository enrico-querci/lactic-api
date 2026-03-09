module Auth
  class Logout
    def self.call(refresh_token:)
      RefreshToken.find_by(token: refresh_token)&.destroy!
    end
  end
end
