class PlayController < ApplicationController
  require 'term/ansicolor'
  require 'pp'
  include Term::ANSIColor

  before_filter :get_ids
  helper_method :jchan

  def get_ids
    require_user or return false
    @me = current_user
    @me_id = @me.id_s

    @game_id = params[:id]

    begin
      @game = Game.find(@game_id, :include => [:users])
    rescue ActiveRecord::RecordNotFound
      redirect_to games_list_url unless @game
      return false
    end

    if !@me.game_id or @me.game_id != @game_id
      @me.game_id = @game_id
      @me.save
    end
  end

  def lock_game
    RedisLockQueue.get_lock @game_id, 5, 5
    @locked = true
  end
  def unlock_game
    #sleep 1 # pretend we take a long time
    RedisLockQueue.release_lock @game_id if @locked
    @locked = false
  end

  def load_game
    @state = GameState.load @game_id
    unless @state
      logger.info "Creating GameState #{@game_id}"
      @state = GameState.new @game_id
      @state.restart
    else
      logger.debug "Loaded game: #{@state.to_json}"
    end

    just_joined = !@state.players.include?(@me_id)
    @state.add_player(@me_id) if just_joined

    @state.player(@me_id).beat_heart

    @state.load_player_users
    became_active, became_inactive =
      @state.update_active_players @game.users.map {|u| u.id_s}

    @players = @state.players_order.map{|id| @state.player(id)}

    became_active << @me_id if just_joined
    jpublish_players_update :added => became_active unless
      became_active.empty? and became_inactive.empty?
  end

  def save_game
    #purged = @state.purge_inactive_players
    purged = nil
    if purged
      jpublish_players_update :removed => purged
    end

    #unless @state.is_saved
      @state.save
      logger.debug 'Saved game: '+@state.to_json
    #end
  end

  def play
    load_game
    # Render template, show state
  end

  def heartbeat
    lock_game
    begin
      load_game
      save_game
    ensure
      unlock_game
    end

    render :text => 'OK'
  end

  def flip_char
    lock_game
    begin
      load_game

      char = @state.flip_char
      save_game
    ensure
      unlock_game
    end

    if char
      jpublish 'pool_update', @me, :body => render_to_string(:partial => 'pool_info')

      msg = "flipped '#{char}'"

      jpublish 'action', @me, :body => msg

      render :json => {:status => true}
    else
      render :json => {:status => false, :message => 'No more letters to flip.'}
    end
  end

  def claim
    word = params[:word].upcase

    lock_game
    begin
      load_game

      result, *resultdata = @state.claim_word(@me_id, word)
      save_game
    ensure
      unlock_game
    end

    case result
    when :ok then
      new_word, words_stolen, pool_used = resultdata
      jpublish_players_update :new_word_id => [@me_id, new_word.id]
      jpublish_pool_update
      
      msg = "claimed #{word} by #{describe_move words_stolen, pool_used}."
      jpublish 'action', @me, :body => msg

      # do this as late as possible so it doesn't matter if this API
      # hangs/takes a long time
      lookup_and_publish_definitions(word.downcase)

      render :json => {:status => true}

    when :word_steal_shares_root then
      validity_info, words_stolen, pool_used = resultdata
      validity, roots_shared = validity_info

      msg = "tried to claim #{word} by "
      msg += describe_move words_stolen, pool_used
      msg += '. But they share the root '
      msg += roots_shared.map{|w|w.upcase}.join ', '
      msg += '.'
      jpublish 'action', @me, :body => msg, :msgclass => 'failed'
      render :json => {:status => false}

    when :word_steal_not_extended then
      validity_info, words_stolen, pool_used = resultdata

      jpublish 'action', @me,
        :body => "tried to claim #{word} by stealing #{words_stolen[0]},"+
                 " but it would be stealing without extending.",
        :msgclass => 'failed'

      render :json => {:status => false}

    when :word_too_short then
      jpublish 'action', @me,
        :body => "tried to claim #{word}, but it's too short.",
        :msgclass => 'failed'

      render :json => {:status => false}

    when :word_not_in_dict then
      jpublish 'action', @me,
        :body => "tried to claim #{word}, but it's not in the dictionary.",
        :msgclass => 'failed'

      render :json => {:status => false}

    when :word_not_available then
      jpublish 'action', @me,
        :body => "tried to claim #{word}, but it's not on the board.",
        :msgclass => 'failed'

      render :json => {:status => false}

    end
  end

  def chat
    jpublish 'chat', @me,
      :body => render_to_string(
        :inline => 'says: <%= message %>',
        :locals => {:message => params[:message]},
      )
    render :text => 'OK'
  end

  def vote_quorum
    (@state.num_active_players + 1) / 2
  end

  def vote_restart
    vote = (params[:vote] != 'false')
    message = (vote ? 'voted to restart' : 'canceled vote')
    do_restart = false

    load_game
    begin
      @state.vote_restart(@me_id, vote)

      num_voted = @state.num_voted_restart
      num_needed = vote_quorum
      message += "<br />#{num_voted} votes/#{num_needed} needed"

      do_restart = num_voted >= num_needed
      if do_restart
        message += "<br /><strong>Game Restarted!</strong>"
        @state.restart
      end
      save_game
    ensure
      unlock_game
    end

    if do_restart
      jpublish_pool_update
      jpublish_players_update :restarted => true
    else
      jpublish_players_update
    end

    jpublish 'action', @me, :body => message
    render :text => 'OK'
  end


  protected

  def jpublish_pool_update
    jpublish 'pool_update', nil, :body => render_to_string(:partial => 'pool_info')
  end

  #def jpublish_refresh_state(game_id)
    #jpublish 'refresh_state', nil, {}, game_id
  #end

  def jpublish_players_update(addl={})
    rendered_players = {}
    @state.players.each do |user_id, player| 
      rendered_players[user_id] =
          render_to_string(:partial => 'player', :object => player)
    end
    jpublish 'players_update', nil, {
      :body => rendered_players,
      :order => @state.players_order,
    }.merge(addl)
  end

  def jpublish(type, from_user, data, game_id=nil)
    from = {}
    from = {:from => {
      :id => from_user.id_s,
      :name => from_user.name,
      :first_name => from_user.first_name,
      :last_name => from_user.last_name,
      :profile_pic => from_user.profile_pic,
    }} if from_user

    out = {:type => type}.merge(from).merge(data)
    #logger.debug green "**PUBLISH** #{PP.pp out,''}"
    Juggernaut.publish jchan(@game_id), out
  end

  def jchan(id)
    "/#{Anathief::JUGGERNAUT_PREFIX}/game/#{id}"
  end


  ### below code could be moved out

  def get_nice_defs(word)
    pos_map = {
      'verb-intransitive' => 'verb (used without object)',
      'verb-transitive' => 'verb (used with object)',
    }

    result = Hash.new do |hash, key|
      hash[key] = Hash.new { |hash2, key2| hash2[key2] = [] }
    end
    raw = Wordnik::Word.find(word).definitions
    raw.each do |d|
      next unless d.text
      pos = d.part_of_speech
      if pos_map.include? pos
        pos = pos_map[pos]
      else
        pos.gsub! /-/, ' ' if pos
      end
      result[d.headword][pos] << d.text
    end
    result[word] = [] if result.empty?

    result
  end

  def lookup_and_publish_definitions(word)
    definitions = get_nice_defs word
    #logger.debug green PP.pp definitions, ''
    jpublish 'definitions', @me, :body => render_to_string(
      :partial => 'definitions',
      :object => definitions,
    )
  end

  def describe_move(words_stolen, pool_used)
    pool_used_letters = pool_used.to_a

    msg = ''
    msg += 'stealing '+words_stolen.join(', ') unless words_stolen.empty?
    if !pool_used_letters.empty?
      msg += words_stolen.empty? ? 'taking' : ' +'
      msg += ' '+pool_used_letters.join(', ') unless pool_used_letters.empty?
    end

    msg = 'doing nothing?!' if msg.empty?
    msg
  end
end
