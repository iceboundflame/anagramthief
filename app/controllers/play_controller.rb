class PlayController < ApplicationController
  before_filter :load_game, :except => [:list]
  after_filter :save_game, :except => [:list]
  helper_method :jchan

  def list
    require_user or return

    @games = Game.all
  end

  def load_game
    require_user or return
    @user = current_user
    @user_id = @user.id_s

    @game_id = params[:id] || @user.game.id
    @game = Game.where(:id => @game_id).limit(1).first
    redirect_to play_list_url unless @game

    @user.game = @game
    @user.save

    @state = GameState.load_from_redis @game_id
    unless @state
      @state = GameState.new @game_id
    end
    logger.debug 'Loaded game: '+@state.to_json
    logger.debug 'Loaded game: '+@state.players.to_json

    @player_profiles = @game.users.inject({}) {|h, user| h[user.id_s] = user; h}
    @player_profiles.each do |id, user|
      @state.add_player(id)
    end

    @other_players = @player_profiles.map { |(id,user)|
      if id != @user_id
        @state.player(id)
      else
        nil
      end
    }.compact
    @me_player = @state.player(@user_id)

    logger.debug 'meplayer: '+@me_player.to_json
  end

  def save_game
    @state.save_to_redis
    logger.debug 'Save game: '+@state.to_json
  end

  def play
    # Render template, show state
  end

  def flip_char
    char = @state.flip_char
    logger.debug "Flipped #{char}"

    jpublish 'pool_update', :body => render_to_string(:partial => 'pool_info')

    render :text => "Flipped #{char}"
  end

  def claim
    word = params[:word].upcase

    unless @state.claim_word(@user_id, word)
      render :text => "Couldn't find #{word}"
      return
    end

    jpublish 'pool_update', :body => render_to_string(:partial => 'pool_info')
    jpublish 'players_update', :body =>
      (@player_profiles.inject({}) do |result, (user_id, user)|
        result[user_id] = render_to_string(
          :partial => 'player_info', :object => @state.player(user_id)
        )
        result
      end)
    render :text => "Claimed #{word}"
  end

  def post
    jpublish 'chat', :body => params[:what]
    render :text => 'OK'
  end


  protected
  def jpublish(type, data)
    Juggernaut.publish(jchan(@game_id), {:type => type}.merge(data))
  end

  def jchan(id)
    "/anathief/game/#{id}"
  end
end
