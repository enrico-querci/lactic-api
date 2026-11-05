module Api
  module V1
    module Coach
      # The coach's own records of their clients: who they are and what to
      # keep in mind. Whether someone has been invited is the invitation's
      # business (ClientInvitationsController, matched by email); the status
      # returned here only reflects it.
      class ClientProfilesController < BaseController
        # GET /api/v1/coach/client_profiles
        def index
          profiles = current_user.client_profiles.order(Arel.sql("LOWER(name)"))
          render json: ClientProfileBlueprint.render(profiles, invitations: pending_invitations)
        end

        # GET /api/v1/coach/client_profiles/:id
        def show
          render json: serialize(find_profile)
        end

        # POST /api/v1/coach/client_profiles
        def create
          profile = current_user.client_profiles.create!(profile_params)
          render json: serialize(profile), status: :created
        end

        # PATCH /api/v1/coach/client_profiles/:id
        def update
          profile = find_profile
          profile.assign_attributes(profile_params)
          ensure_email_unchanged_once_invited(profile)
          profile.save!
          render json: serialize(profile)
        end

        # DELETE /api/v1/coach/client_profiles/:id
        #
        # Only for someone who has not joined. A client is removed with
        # DELETE /clients/:id, which keeps the profile.
        def destroy
          profile = find_profile
          if profile.linked?
            return render json: { error: "This person is already your client. Remove them as a client first.",
                                  code: "client_active" }, status: :conflict
          end

          ClientProfile.transaction do
            pending_invitations[profile.email]&.revoke!
            profile.destroy!
          end
          head :no_content
        end

        private

        def find_profile
          current_user.client_profiles.find(params[:id])
        end

        def serialize(profile)
          ClientProfileBlueprint.render(profile, invitations: pending_invitations)
        end

        # Invitations a person could still accept, by email.
        def pending_invitations
          @pending_invitations ||= current_user.client_invitations.pending
                                               .where("expires_at > ?", Time.current).index_by(&:email)
        end

        # The email is how the invitation finds the profile, so it is fixed
        # once an invitation exists or the person has joined.
        def ensure_email_unchanged_once_invited(profile)
          return unless profile.email_changed?
          return unless profile.linked? || pending_invitations.key?(profile.email_was)

          profile.errors.add(:email, "can't be changed once the person has been invited")
          raise ActiveRecord::RecordInvalid, profile
        end

        def profile_params
          params.permit(:name, :email, :phone, :level, :goal, :limitations, :notes)
        end
      end
    end
  end
end
