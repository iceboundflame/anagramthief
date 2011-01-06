class AddScores < ActiveRecord::Migration
  def self.up
    create_table :records do |t|
      t.integer :gameroom_id
      t.text :data

      t.timestamps
    end

    create_table :user_records do |t|
      t.integer :record_id
      t.integer :user_id
      t.integer :num_letters
      t.text :data
      t.integer :rank
    end
  end

  def self.down
    drop_table :records
    drop_table :user_records
  end
end
