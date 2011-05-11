class WelcomeController < ApplicationController
  def index
    on_canvas = process_signed_request
    if user_signed_in?
      game_id = params[:game_id] || session[:go_to_game_id]
      if game_id
        session.delete :go_to_game_id
        redirect_to play_url(game_id)
      else
        redirect_to games_list_url 
      end
    else
      # Render sign-in link
      session[:go_to_game_id] = params[:game_id] if params[:game_id]
      @guest_name = random_guest_name
    end
  end
end
