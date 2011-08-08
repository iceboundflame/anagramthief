require 'name_generator'

class BotsController < ApplicationController
  before_filter :get_ids

  PERSONALITIES = [
    {
      :title => 'Baby',
      :settings => {
          :max_rank => 10000,
          :max_steal_len => 3,
          :max_word_len => 0,
          :delay_ms_mean => 9500,
          :delay_ms_stdev => 3000,
          :delay_ms_per_kcost => 50,
          :delay_ms_per_word_considered => 0,
      },
    },
    {
      :title => '',
      :settings => {
          :max_rank => 30000,
          :max_steal_len => 5,
          :max_word_len => 0,
          :delay_ms_mean => 7500,
          :delay_ms_stdev => 2000,
          :delay_ms_per_kcost => 30,
          :delay_ms_per_word_considered => 0,
      },
    },
    {
      :title => 'Master',
      :settings => {
          :max_rank => 0,
          :max_steal_len => 0,
          :max_word_len => 0,
          :delay_ms_mean => 2500,
          :delay_ms_stdev => 3000,
          :delay_ms_per_kcost => 10,
          :delay_ms_per_word_considered => 0,
      },
    },
  ]

  def add
    level = params[:level] || 0
    level = level.to_i

    level = 0 if !level or level < 0 or level >= PERSONALITIES.length

    personality = PERSONALITIES[level]
    name = "#{personality[:title]} #{NameGenerator.random_name}"
    suffix = "(Bot, Lv.#{level})"

    botuser = User.create :uid => nil,
      :name => "#{name} #{suffix}",
      :first_name => name,
      :last_name => suffix

    play_token = generate_play_token botuser.id, @game_id
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
