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
          client.update!(coach: nil)
          head :no_content
        end
      end
    end
  end
end
