class AddWinsLosses < ActiveRecord::Migration
  def self.up
    add_column :users, :wins, :integer, :default => 0
    add_column :users, :games_completed, :integer, :default => 0
  end

  def self.down
    remove_column :users, :wins
    remove_column :users, :games_completed
  end
end
