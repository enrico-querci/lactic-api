Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post   "auth",         to: "auth#create"
      delete "auth",         to: "auth#destroy"
      post   "auth/refresh", to: "auth#refresh"

      # Dev-only login — route does not exist in production
      if Rails.env.development? || Rails.env.test?
        post "auth/dev_login", to: "auth#dev_login"
      end
    end
  end
end
