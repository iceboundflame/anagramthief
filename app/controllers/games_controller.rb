class GamesController < ApplicationController
  before_filter :require_user

  def list
    purge_empty_games

    friend_game_ids = []
    begin
      @fb = MiniFB::OAuthSession.new(session[:tok], 'en_US')
      @friend_ids = @fb.get('me/friends')['data'].map { |x| x['id'] }
      @friend_ids << current_user.uid

      @friend_games = Game.includes(:users)
        .where(:users => {:uid => @friend_ids}).all

      @my_games = sort_games_by_user_ct Game.includes(:users)
        .where(:creator_id => current_user.id).all

      my_game_ids = @my_games.map{|g| g.id}

      @friend_games = sort_games_by_friend_ct @friend_games
        .delete_if {|g| my_game_ids.include? g.id }
      friend_game_ids = @friend_games.map{|g| g.id}
    rescue MiniFB::FaceBookError
      logger.error "FB error in games_list: #{$!}"

      logger.info "Lost login state"
      session[:uid] = session[:tok] = nil

      redirect_to root_url
      return
    end

    @public_games = Game.includes(:creator, :users)
      .delete_if {|g| friend_game_ids.include? g.id or
                      my_game_ids.include? g.id}
    @public_games = sort_games_by_user_ct @public_games
  end

  def create
    game = Game.new(
      :name => params['game-name'],
      :is_private => params['game-private'],
      :creator => current_user,
    )
    if game.save
      redirect_to play_url(game.id)
    else
      flash[:create_errors] = game.errors.full_messages
      redirect_to games_list_url
    end
  end

  protected
  def sort_games_by_user_ct(list)
    list.sort { |g1, g2| (g2.users.size) <=> (g1.users.size) }
  end
  def sort_games_by_friend_ct(list)
    list.sort { |g1, g2|
      (g2.users.select {|u| @friend_ids.include? u.uid}.size) <=>
      (g1.users.select {|u| @friend_ids.include? u.uid}.size)
    }
  end

  # FIXME: Race condition, people joining the game and this list getting
  # updated at the same time?
  # Need some stale games first only hide for 2 min then timeout and purge?
  def purge_empty_games
    empty_game_ids = Game.includes(:users)
      .where(:users => {:id => nil}).map {|g|g.id}

    return if empty_game_ids.empty?

    #Game.includes(:users)
      #.where(:users => {:id => nil}).all.map {|g|g.id}
      #.delete_all(:game_ids)
    logger.info "Deleting empty games #{empty_game_ids}"
    Game.delete_all(:id => empty_game_ids)
    GameState.delete_ids(empty_game_ids)
  end
end
