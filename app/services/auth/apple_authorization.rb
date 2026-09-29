module Auth
  # Keeps the one thing needed to honour App Review guideline 5.1.1(v): a
  # refresh token to revoke when an account that used Sign in with Apple is
  # deleted.
  #
  # Neither call can fail the request around it. A sign-in that cannot
  # reach Apple still signs in, and a deletion still deletes — leaving a
  # user's data behind because Apple was unreachable would be the worse
  # failure. Both are reported instead.
  #
  # The token is stored unencrypted, deliberately. Without the Sign in with
  # Apple private key it cannot be used at all, and with it the only thing
  # it grants is the ability to revoke this app's own authorization — there
  # is no Apple user data behind it. Active Record encryption is not set up
  # in this app, and adding its keys for this alone was not worth it.
  module AppleAuthorization
    def self.remember(user:, code:, client_id:, client: AppleTokenClient.new)
      return if code.blank? || client_id.blank? || !client.configured?

      token = client.exchange(code: code, client_id: client_id)
      user.update!(apple_refresh_token: token, apple_client_id: client_id)
    rescue AppleTokenClient::Error => e
      report(e, user)
    end

    def self.revoke(user, client: AppleTokenClient.new)
      return if user.apple_refresh_token.blank? || !client.configured?

      client.revoke(refresh_token: user.apple_refresh_token, client_id: user.apple_client_id)
    rescue AppleTokenClient::Error => e
      report(e, user)
    end

    def self.report(error, user)
      Rails.logger.warn("[sign_in_with_apple] #{error.message} (user #{user.id})")
      Sentry.capture_exception(error)
    end
    private_class_method :report
  end
end
