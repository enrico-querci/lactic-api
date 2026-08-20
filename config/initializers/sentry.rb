if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn         = ENV["SENTRY_DSN"]
    config.environment = Rails.env
    config.release     = ENV["RAILWAY_GIT_COMMIT_SHA"]

    # false is what actually keeps PII out of the request side of an event:
    # with it off, the SDK never attaches the request body, cookies, query
    # string, or Authorization header, and strips IP-bearing headers before
    # anything else runs (see sentry-ruby's RequestInterface#initialize).
    # User context is attached explicitly (id + role only, see
    # Authenticatable) and never derived from the request.
    config.send_default_pii = false

    # Errors only for the pilot; tracing is volume and cost we don't need yet.
    config.traces_sample_rate = 0.0

    config.breadcrumbs_logger = [ :active_support_logger ]

    # sentry-rails' default action_controller breadcrumb includes :params
    # verbatim from ActiveSupport::Notifications, with no pass through
    # filter_parameters — confirmed by reading the source
    # (Sentry::Rails::Breadcrumb::ActiveSupportLogger#add slices the allowed
    # keys but never filters their values). A client-signup or login
    # breadcrumb would otherwise carry a raw email in plain text. Drop
    # :params from both action_controller entries; keep everything else,
    # which is routing/timing context with no PII in it.
    config.rails.active_support_logger_subscription_items["start_processing.action_controller"] =
      %i[controller action format method path]
    config.rails.active_support_logger_subscription_items["process_action.action_controller"] =
      %i[controller action format method path status view_runtime db_runtime]

    # ErrorHandling (app/controllers/concerns/error_handling.rb) already turns
    # these into clean, expected responses (404/422/400) — they are routine
    # traffic, not bugs. RecordNotFound and ParameterMissing are already in
    # sentry-rails' own default ignore list; RecordInvalid isn't, but is
    # rescued the same way and belongs with them. The Catalog error classes
    # are internal states the services already document as non-failures
    # (NotConfigured) or already-retried (Transient, Quota) — see
    # app/services/catalog/providers/errors.rb and
    # app/services/catalog/translation/errors.rb.
    config.excluded_exceptions += %w[
      ActiveRecord::RecordInvalid
      Catalog::Translation::Errors::NotConfigured
      Catalog::Providers::Errors::Transient
      Catalog::Providers::Errors::Quota
    ]

    # Defense-in-depth for `extra:` context a future explicit capture call
    # might add. send_default_pii=false above already keeps the request body
    # and headers off the event; this reuses the same scrub list
    # config/initializers/filter_parameter_logging.rb already applies to
    # logs, rather than keeping a second list in sync by hand.
    scrubber = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    config.before_send = lambda do |event, _hint|
      event.extra = scrubber.filter(event.extra) if event.extra.present?
      event
    end
  end
end
