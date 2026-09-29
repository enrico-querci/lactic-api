module Api
  module V1
    module Coach
      # App Review guideline 5.1.1(v): Lactic Studio creates accounts, so it
      # must also let a coach delete theirs from inside the app.
      class AccountController < BaseController
        # DELETE /api/v1/coach/account
        #
        # Clients survive as users with no coach (User#clients nullifies),
        # but everything the coach owns goes: programs, and through them
        # the assignments and logged sessions that hang off those programs,
        # plus custom exercises, templates and invitations.
        #
        # Refused while a paid plan will still renew. Billing runs through
        # RevenueCat on the web, and deleting the account would leave a
        # subscription charging somebody who can no longer sign in to cancel
        # it.
        def destroy
          subscription = current_user.coach_subscription
          if subscription&.active? && subscription.auto_renew
            return render json: {
              error: "Cancel your Lactic Studio subscription on the web before deleting your account",
              code: "subscription_active"
            }, status: :conflict
          end

          # Before the destroy, which takes the stored token with it. Never
          # blocks the deletion: see Auth::AppleAuthorization.
          Auth::AppleAuthorization.revoke(current_user)
          User.transaction do
            # Templates first: User destroys programs before templates, and a
            # program's workouts would try to nullify the templates' NOT NULL
            # source_workout_id on the way out.
            current_user.workout_templates.destroy_all
            current_user.destroy!
          end
          head :no_content
        end
      end
    end
  end
end
