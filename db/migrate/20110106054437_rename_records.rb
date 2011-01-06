class RenameRecords < ActiveRecord::Migration
  def self.up
    rename_table :records, :game_records
    rename_table :user_records, :user_game_records

    rename_column :user_game_records, :record_id, :game_record_id
  end

  def self.down
    rename_column :user_game_records, :game_record_id, :record_id

    rename_table :game_records, :records
    rename_table :user_game_records, :user_records
  end
end
