# A JSON interface for the AppServer to call back with tasks that require
# database connectivity: for example, recording game records.
class InternalController < ApplicationController
  before_filter :verify_internal

  def endpoint
    case params[:cmd]
    when 'touch_game'
      game_id = params[:game_id]
      logger.info "Updating game timestamp #{game_id}"
      Game.find(game_id).touch
      render :json => {:status => true}

    when 'record_game'
      # from GameState.game_record_data
      # passed thru AppServer.record_game
      game_id = params[:game_id]
      completed = (params[:completed] != 'false')
      stats_data = JSON.parse(params[:stats_data])
      rank_data = JSON.parse(params[:rank_data])
      player_data = JSON.parse(params[:player_data])

      r = GameRecord.create(
        :gameroom_id => game_id,
        :data => stats_data,
        :completed => completed,
      )

      users = Hash[ User.find(rank_data.map {|info| info['id']}).map {|user|
        [user.id.to_s, user]
      }]
      rank_data.each do |info|
        p = player_data[info['id']]
        user = users[info['id']]
        UserGameRecord.create(
          :game_record => r,
          :user => user,
          :num_letters => p['score'],
          :data => {
            :claims => p['claims'],
          }.to_json,
          :rank => info['rank'],
        )

        if completed
          user.wins += 1 if info['rank'] == 1
          user.games_completed += 1
          user.save
        end
      end

      render :json => {:status => true}
    else
      raise "Unknown command"
    end
  end

  protected
  def verify_internal
    unless Anathief::Internal::ALLOWED_HOSTS.include? request.remote_ip
      logger.error "Stopped an attempted /internal access from #{request.remote_ip}"
      raise ActionController::RoutingError.new('Not Found')
    end
    return true
  end
end
