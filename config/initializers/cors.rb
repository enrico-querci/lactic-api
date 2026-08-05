Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(
      "http://localhost:3000",   # Next.js dev server
      "http://localhost:3001",   # alternate dev port
      *ENV.fetch("CORS_ORIGINS", "").split(",").map(&:strip).reject(&:empty?)
    )

    resource "/api/*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      # A browser can only read a response header on a cross-origin request if
      # it is listed here. The pagination metadata deliberately travels in
      # headers rather than a wrapper object, so without this the web client
      # sees null for all of them and silently renders no pagination controls —
      # which is exactly what happened before this was added.
      expose: %w[
        Authorization
        X-Total-Count
        X-Page
        X-Per-Page
        X-Total-Pages
      ],
      max_age: 3600
  end
end
