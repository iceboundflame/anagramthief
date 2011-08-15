require 'name_generator'

class BotsController < ApplicationController
  before_filter :get_ids

  def add
    level = params[:level] || 0
    level = level.to_i

    personality_names = BotPersonalities.instance.all_titles
    level = 0 if !level or level < 0 or level >= personality_names.length

    personality = BotPersonalities.instance.get level
    name = "#{personality[:title]} #{NameGenerator.random_name}"
    suffix = "(Lv.#{level} Bot)"

    botuser = User.create :uid => nil,
      :name => "#{name} #{suffix}",
      :first_name => name,
      :last_name => suffix

    play_token = generate_play_token botuser.id, @game_id, :is_robot => true
    logger.info "Created robot user: #{botuser.name}"

    resp = BotControlConnection.instance.request('add_bot', {
      :user_id => botuser.id,
      :play_token => play_token,
      :settings => personality[:settings],
    })
    if resp and resp['ok']
      logger.info "Vivified robot #{botuser.name} with token #{play_token}"
      render :json => {:status => true}
    else
      logger.info "Problematic response from bot control server: #{resp}"
      render :json => {:status => false}
    end
  end

  def remove
    resp = BotControlConnection.instance.request('remove_bot', {
      :user_id => params[:bot_id],
    })
    if resp and resp['ok']
      logger.info "Shut down robot #{params[:bot_id]}"
      render :json => {:status => true}
    else
      logger.info "Problematic response from bot control server: #{resp}"
      render :json => {:status => false}
    end
  end

  protected

  def get_ids
    require_user or return false
    @me = current_user
    @me_id = @me.id_s

    @game_id = params[:game_id]

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
end
