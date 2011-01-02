class AddPermagame < ActiveRecord::Migration
  def self.up
    add_column :games, :permanent, :boolean, :default => false
  end

  def self.down
    remove_column :games, :permanent
  end
end
