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
      expose: %w[Authorization],
      max_age: 3600
  end
end
