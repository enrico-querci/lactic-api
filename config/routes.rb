Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post   "auth",         to: "auth#create"
      delete "auth",         to: "auth#destroy"
      post   "auth/refresh", to: "auth#refresh"

      # RevenueCat calls this directly — no user session exists yet, so it
      # is authenticated by its own signature/shared-secret check rather
      # than a JWT. See Api::V1::Webhooks::RevenueCatController.
      post "webhooks/revenuecat", to: "webhooks/revenue_cat#create"

      resources :client_invitations, only: :show, param: :token do
        post :accept, on: :member
      end

      # Dev-only login — route does not exist in production
      if Rails.env.development? || Rails.env.test?
        post "auth/dev_login", to: "auth#dev_login"
      end

      # Current user profile
      get   "me", to: "me#show"
      patch "me", to: "me#update"

      # Exercise animation proxy. Shared rather than namespaced per role,
      # because coaches and clients render the same media and only the
      # visibility rule differs. The path matches what ExerciseBlueprint
      # serializes as animation_url.
      resources :exercises, only: [] do
        resource :animation, only: %i[show], controller: "exercise_animations"
      end

      # Coach endpoints
      namespace :coach do
        resources :client_invitations, only: %i[index create destroy] do
          post :resend, action: :resend_invitation, on: :member
        end

        resources :clients, only: %i[index show destroy] do
          resources :progress, only: %i[index show], controller: "client_progress"
        end

        resources :exercises, only: %i[index show create update destroy]
        # Singular `resource` would default to a plural controller name; this
        # is a singleton, so point it at the singular one.
        resource :exercise_taxonomy, only: %i[show], controller: "exercise_taxonomy"

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

        # Singular `resource` would default to a plural controller name;
        # this is a singleton (there is exactly one "my subscription"), so
        # point it at the singular one. Mirrors exercise_taxonomy/account.
        resource :subscription, only: %i[show], controller: "subscription" do
          post :sync, on: :member
        end
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

        # Singular `resource` would default to a plural controller name; this
        # is a singleton (there is exactly one "my account"), so point it at
        # the singular one. Mirrors the coach exercise_taxonomy precedent.
        resource :account, only: %i[destroy], controller: "account"
      end
    end
  end
end
