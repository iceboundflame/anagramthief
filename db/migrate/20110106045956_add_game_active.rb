class AddGameActive < ActiveRecord::Migration
  def self.up
    add_column :games, :active, :boolean, :default => true
  end

  def self.down
    remove_column :games, :active
  end
end
