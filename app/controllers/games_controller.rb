class GamesController < ApplicationController
  before_filter :require_user
  def list
    begin
      @fb = MiniFB::OAuthSession.new(session[:tok], 'en_US')
      friend_ids = @fb.get('me/friends')['data'].map { |x| x['id'] }
      friend_ids << current_user.uid

      @friend_games = Game.includes(:users).where(:users => {:uid => friend_ids})

    #rescue
      #logger.error "Error in compute_scores: #{$!}"
    end

    @public_games = Game.includes(:creator, :users)
  end

  def create
    game = Game.new(params[:game])
    game.creator = current_user
    if game.save
      redirect_to play_url(game.id)
    else
      flash[:create_errors] = 'Error: '+game.errors.join(', ')
      redirect_to games_list_url
    end
  end
end
