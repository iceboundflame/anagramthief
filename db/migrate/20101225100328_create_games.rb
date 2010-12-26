class CreateGames < ActiveRecord::Migration
  def self.up
    create_table :games do |t|
      t.string :name
      t.datetime :created_at
      t.datetime :updated_at
      t.text :data

      t.timestamps
    end
  end

  def self.down
    drop_table :games
  end
end
