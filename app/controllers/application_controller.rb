class ApplicationController < ActionController::API
  include Authenticatable
  include Authorizable
end
