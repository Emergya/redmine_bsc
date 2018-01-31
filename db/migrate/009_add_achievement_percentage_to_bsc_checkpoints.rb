class AddAchievementPercentageToBscCheckpoints < ActiveRecord::Migration
  def self.up
    add_column :bsc_checkpoints, :achievement_percentage, :integer, :null => false
  end

  def self.down
    remove_column :bsc_checkpoints, :achievement_percentage
  end
end
