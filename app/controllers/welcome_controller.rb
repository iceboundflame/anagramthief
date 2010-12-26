class WelcomeController < ApplicationController
  def index
    redirect_to play_list_url if user_signed_in?
  end
end
