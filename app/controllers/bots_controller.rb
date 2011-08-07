class BotsController < ApplicationController
  before_filter :get_ids

  def add
    name = "Rob"
    botuser = User.create :uid => nil,
      :name => "#{name} (Bot)",
      :first_name => name,
      :last_name => "(Bot)"

    play_token = generate_play_token botuser.id, @game_id

    puts "\n\n\n\nConnect"
    Socket.tcp(Anathief::BotControl::CONNECT_HOST,
               Anathief::BotControl::PORT) {|sock|
      puts "Send"
      sock.send({
        :_t => 'add_bot',
        :user_id => botuser.id,
        :play_token => play_token,
        :settings => {
          :max_rank => 30000,
          :max_steal_len => 5,
          :max_word_len => 0,
          :delay_ms_mean => 7500,
          :delay_ms_stdev => 2000,
          :delay_ms_per_kcost => 30,
          :delay_ms_per_word_considered => 0,
        },
      }.to_json + "\r\n", 0)
    }

    logger.info "Created robot: #{botuser.name}"

    render :json => {:status => true}
  end

  def remove
    Socket.tcp(Anathief::BotControl::CONNECT_HOST,
               Anathief::BotControl::PORT) {|sock|
      sock.send({
        :_t => 'remove_all_bots',
      }.to_json + "\r\n", 0)
    }
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
