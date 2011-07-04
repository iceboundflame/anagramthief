class PlayController < ApplicationController
  #require 'term/ansicolor'
  #require 'pp'
  #include Term::ANSIColor
  
  before_filter :get_ids

  def play
    # Render template, show state
    # 
    @id_token = "#{@me_id}:#{@game_id}:#{Time.now.to_i}:"
    @id_token += Digest::SHA1.hexdigest(@id_token + Anathief::Application.config.secret_token)
  end

  def invite_form
    # just render
  end


  protected

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

      # need to reload this because now this user is in the @game.users list too
      @game = Game.find(@game_id, :include => [:users])
    end
  end

  #def update_users_not_in_game
    #return unless @state

    #remove = []
    #@game.users.each {|u|
      #remove << u.id unless @state.players.include? u.id_s
    #}
    #unless remove.empty?
      #User.update_all({:game_id => nil}, {:id => remove})
      #logger.info "Removed game from users #{remove.join ', '}"
    #end
  #end

  #def touch_game
    #return unless @game
    #@game.update_attributes(:updated_at => Time.now)
  #end

  #def describe_move(words_stolen, pool_used)
    #pool_used_letters = pool_used.to_a

    #msg = ''
    #msg += 'stealing '+words_stolen.join(', ') unless words_stolen.empty?
    #if !pool_used_letters.empty?
      #msg += words_stolen.empty? ? 'taking' : ' +'
      #msg += ' '+pool_used_letters.join(', ') unless pool_used_letters.empty?
    #end

    #msg = 'doing nothing?!' if msg.empty?
    #msg
  #end
end
