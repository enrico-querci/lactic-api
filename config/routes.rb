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

      # Current user profile
      get   "me", to: "me#show"
      patch "me", to: "me#update"

      # Coach endpoints
      namespace :coach do
        resources :clients, only: %i[index show destroy] do
          resources :progress, only: %i[index show], controller: "client_progress"
        end

        resources :exercises, only: %i[index create update destroy]

        resources :programs, only: %i[index show create update destroy] do
          resources :weeks, only: %i[index show create update destroy] do
            resources :workouts, only: %i[index show create update destroy] do
              post :duplicate, on: :member
            end
          end
        end

        resources :workouts, only: [] do
          resources :workout_exercises, only: %i[index create update destroy]
        end

        resources :workout_templates, only: %i[index show create destroy] do
          post :apply, on: :member
        end

        resources :program_assignments, only: %i[index show create update destroy]
      end

      # Client endpoints
      namespace :client do
        resources :programs, only: %i[index show]
        resources :workouts, only: %i[show]

        resources :exercises, only: %i[index show] do
          get :history, on: :member
        end

        resources :workout_sessions, only: %i[index show create update]
        resources :exercise_logs, only: %i[create update]
        resources :set_logs, only: %i[create update destroy]
      end
    end
  end
end
