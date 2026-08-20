ENV["RAILS_ENV"] ||= "test"
ENV["JWT_SECRET_KEY"] ||= "test-jwt-secret-key-not-for-production"
# Deterministic regardless of what's in the shell environment: tests never
# talk to Sentry. Deleted (not just left unset) so a DSN exported for local
# manual testing can't leak into a parallelized test run.
ENV.delete("SENTRY_DSN")
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Returns auth headers with a valid JWT for the given user fixture.
    # Usage: get "/api/v1/something", headers: auth_headers_for(users(:client_alice))
    def auth_headers_for(user)
      token = JwtService.encode(user_id: user.id)
      { "Authorization" => "Bearer #{token}" }
    end
  end
end
