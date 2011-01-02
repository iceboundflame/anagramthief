class Game < ActiveRecord::Base
  has_many :users
  belongs_to :creator, :class_name => 'User'

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
    # deleted, ensure that the purge_old timeout is much greater than
    # the time out here.
    self.where('games.permanent = ? OR games.updated_at > ?', true, 3.hour.ago)
  end

  def self.purge_old
    purge_game_ids = self.includes(:users)
      .where(:permanent => false)
      .where('games.updated_at < ?', 1.day.ago)
      .map {|g|g.id}

    return if purge_game_ids.empty?

    # end game -- updates user stats if game completed
    purge_game_ids.each do |gid|
      gs = GameState.load gid
      gs.end_game
    end

    logger.info "Deleting old games #{purge_game_ids}"
    Game.delete_all(:id => purge_game_ids)
    GameState.delete_ids(purge_game_ids)
  end
end
