class WelcomeController < ApplicationController
  def index
    on_canvas = process_signed_request
    redirect_to games_list_url if user_signed_in?
  end
end
