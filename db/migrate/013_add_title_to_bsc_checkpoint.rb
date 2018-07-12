class AddTitleToBscCheckpoint < ActiveRecord::Migration
  def self.up
    add_column :bsc_checkpoints, :title, :text, :default => nil, :null => true
  end

  def self.down
    remove_column :bsc_checkpoints, :title
  end
end
