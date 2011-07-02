class GamesController < ApplicationController
  before_filter :require_user

  def list
    Game.process_inactive

    @my_games = sort_games_by_user_ct Game.includes(:users)
      .where(:creator_id => current_user.id).all

    my_game_ids = @my_games.map{|g| g.id}

    friend_game_ids = []
    @friend_games = []
    @friend_ids = []
    if session[:fb_tok]
      begin
        @fb = MiniFB::OAuthSession.new(session[:fb_tok], 'en_US')
        @friend_ids = @fb.get('me/friends')['data'].map { |x| x['id'] }
        @friend_ids << current_user.uid

        @friend_games = Game.hide_old.includes(:users)
          .where(:users => {:uid => @friend_ids}).all

        @friend_games = sort_games_by_friend_ct @friend_games
          .delete_if {|g| my_game_ids.include? g.id }
        friend_game_ids = @friend_games.map{|g| g.id}
      rescue MiniFB::FaceBookError
        logger.error "FB error in games_list: #{$!}"

        logger.info "Lost login state"
        session[:fb_uid] = session[:fb_tok] = nil

        redirect_to root_url
        return
      end
    end

    @public_games = Game.hide_old.includes(:creator, :users)
      .delete_if {|g| friend_game_ids.include? g.id or
                      my_game_ids.include? g.id}
    @public_games = sort_games_by_user_ct @public_games

    @my_recent_records = GameRecord
      .includes({:user_game_records => :user, :gameroom => :creator})
      .where(:user_game_records => {:user_id => current_user.id})
      .order('game_records.created_at DESC')
      .limit(8)
      .all

    @recent_records = GameRecord
      .includes({:user_game_records => :user, :gameroom => :creator})
      .order('game_records.created_at DESC')
      .limit(8)
      .all

    Game.end_old

    respond_to do |format|
      format.json {
        games_json = []
        [*@public_games, *@friend_games, *@my_games].each do |g|
          games_json << {
            :name => g.name,
            :players => g.users.all.map { |u| u.name }.join(', '),
            :id => g.id,
          }
        end
        render :json => {:status => true,
          :games => games_json,
        }
      }
      format.html {}
    end
  end

  def create
    game = Game.new(
      :name => params['game-name'],
      #:is_private => params['game-private'],
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
end
