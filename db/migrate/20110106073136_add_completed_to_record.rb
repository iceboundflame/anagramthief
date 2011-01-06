class AddCompletedToRecord < ActiveRecord::Migration
  def self.up
    add_column :game_records, :completed, :boolean, :default => true
  end

  def self.down
    remove_column :game_records, :completed
  end
end
