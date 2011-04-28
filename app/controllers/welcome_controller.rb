class WelcomeController < ApplicationController
  def index
    on_canvas = process_signed_request
    if on_canvas
      if user_signed_in?
        parms = session[:index_params] || params
        session.delete :index_params
        if parms[:game_id]
        #if parms['game_id']
          redirect_to play_url(parms['game_id'])
        else
          redirect_to games_list_url 
        end
      else
        # Render sign-in link
        session[:game_id] = params
      end
    #
      #redirect_to Facebook::CANVAS_URL
    end

    @guest_name = random_guest_name
  end
end
