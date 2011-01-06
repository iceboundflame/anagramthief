class GameRecord < ActiveRecord::Base
  has_many :user_game_records
  has_many :users, :through => :user_game_records

  belongs_to :gameroom, :class_name => 'Game'
end
