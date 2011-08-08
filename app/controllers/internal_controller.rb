# A JSON interface for the AppServer to call back with tasks that require
# database connectivity: for example, recording game records.
class InternalController < ApplicationController
  before_filter :verify_internal

  def endpoint
    case params[:cmd]
    when 'touch_game'
      logger.info "Updating game timestamp #{game_id}"
      Game.find(params[:game_id]).touch
      render :json => {:status => true}

    when 'create_game_record'
      game_id = params[:game_id]
      stats_data = params[:stats_data]
      completed = params[:completed]
      rank_data = JSON.parse(params[:rank_data])
      player_data = JSON.parse(params[:player_data])

      r = GameRecord.create(
        :gameroom_id => game_id,
        :data => stats_data,
        :completed => completed,
      )
      rank_data.each do |info|
        p = player_data[info['id']
        UserGameRecord.create(
          :game_record => r,
          :user => info['id']
          :num_letters => p['score'],
          :data => {
            :claims => p['claims'],
          }.to_json,
          :rank => info['rank'],
        )
      end

      # RECORD USER STATS
      #winner_ids.each do |id|
        #@players[id].user.wins += 1
      #end

      #@players.values.each do |p|
        #u = p.user
        #u.games_completed += 1
        #u.save
      #end


    else
      raise "Unknown command"
    end
  end

  protected
  def verify_internal
    unless Anathief::Internal.ALLOWED_HOSTS.include? request.remote_ip
      raise ActionController::RoutingError.new('Not Found')
    end
    return true
  end
end
