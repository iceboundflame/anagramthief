class AddCreatorGame < ActiveRecord::Migration
  def self.up
    add_column :games, :creator_id, :integer
    add_column :games, :is_private, :boolean, :default => false
    remove_column :games, :data
  end

  def self.down
    remove_column :games, :creator_id
    remove_column :games, :is_private
    add_column :games, :data, :text
  end
end
