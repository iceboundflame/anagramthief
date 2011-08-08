require 'app_server/game_state'

  # N.B. not thread-safe!
class AppServer::GameStore
  def initialize
    @games = {}
  end

  # N.B. not thread-safe!
  def find_or_create_game(game_id)
    if @games.include? game_id
      return @games[game_id]
    else
      game = AppServer::GameState.new game_id
      game.restart
      @games[game_id] = game
      return game
    end
  end

  def get(game_id)
    raise "Game #{game_id} not in store" unless @games.include? game_id
    @games[game_id]
  end
end
