class WelcomeController < ApplicationController
  def index
    on_canvas = process_signed_request
    if user_signed_in?
        puts "getting go_to_game_id to #{session[:go_to_game_id]}"
      game_id = params[:game_id] || session[:go_to_game_id]
        puts "go_to_game_id is #{game_id}"
      if game_id
        session.delete :go_to_game_id
        redirect_to play_url(game_id)
      else
        redirect_to games_list_url 
      end
    else
      # Render sign-in link
      if params[:game_id]
        session[:go_to_game_id] = params[:game_id]
        puts "Setting go_to_game_id to #{session[:go_to_game_id]}"
      end
      @guest_name = random_guest_name
    end
  end
end
