module Api
  module V1
    class BaseController < ApplicationController
      include ErrorHandling
    end
  end
end
