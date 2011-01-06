class UserGameRecord < ActiveRecord::Base
  belongs_to :game_record
  belongs_to :user
end
