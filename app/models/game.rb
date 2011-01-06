class Game < ActiveRecord::Base
  has_many :users
  belongs_to :creator, :class_name => 'User'

  has_many :game_records

  validates :name, :presence => true, :length => {:maximum => 30}
  validates :creator, :presence => true

  def self.process_inactive
    self.includes(:users).where('games.updated_at < ?', 1.minute.ago).each do |g|
      # remove users
      user_ids = g.users.map {|u| u.id}
      User.update_all({:game_id => nil}, {:id => user_ids})
    end

    self
  end

  def self.hide_old
    # To prevent people joining a game that's in the process of being
    # deleted, ensure that the purge_old timeout is greater than
    # the timeout here.
    self.where('games.permanent = ? OR games.updated_at > ?', true, 3.hour.ago)
  end

  def self.end_old
    end_game_ids = self.includes(:users)
      .where('games.updated_at < ?', 4.hour.ago)
      .where(:active => true)
      .map {|g|g.id}

    return if end_game_ids.empty?

    # end game -- updates user stats if game completed
    end_game_ids.each do |gid|
      gs = GameState.load gid
      next unless gs
      gs.load_player_users
      gs.end_game
      # no save because we're about to delete the GameState!
    end

    logger.info "Deleting old games #{end_game_ids}"
    # let's keep the Game around, just delete the GameState
    Game.update_all({:active => false}, {:id => end_game_ids})
    GameState.delete_ids(end_game_ids)
  end
end
