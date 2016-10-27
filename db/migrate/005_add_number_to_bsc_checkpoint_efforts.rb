class AddNumberToBscCheckpointEfforts < ActiveRecord::Migration
  def self.up
    add_column :bsc_checkpoint_efforts, :number, :float, :default => 0.0, :null => false
  end

  def self.down
    remove_column :bsc_checkpoint_efforts, :number
  end
end
