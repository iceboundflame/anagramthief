class AddUserGame < ActiveRecord::Migration
  def self.up
    add_column :users, :game_id, :integer
  end

  def self.down
    remove_column :users, :game_id
  end
end
