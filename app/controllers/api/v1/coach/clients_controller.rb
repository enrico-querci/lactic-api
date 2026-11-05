module Api
  module V1
    module Coach
      class ClientsController < BaseController
        # GET /api/v1/coach/clients
        def index
          clients = current_user.clients
          render json: UserBlueprint.render(clients)
        end

        # GET /api/v1/coach/clients/:id
        def show
          client = current_user.clients.find(params[:id])
          render json: UserBlueprint.render(client)
        end

        # DELETE /api/v1/coach/clients/:id
        def destroy
          client = current_user.clients.find(params[:id])
          # The profile is kept, back to "prepared": notes about someone are
          # not lost by ending the relationship, and the coach can invite them
          # again or delete the profile deliberately.
          User.transaction do
            client.update!(coach: nil)
            current_user.client_profiles.where(user_id: client.id).update_all(user_id: nil, updated_at: Time.current)
          end
          head :no_content
        end
      end
    end
  end
end
