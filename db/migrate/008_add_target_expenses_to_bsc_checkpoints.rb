class AddTargetExpensesToBscCheckpoints < ActiveRecord::Migration
  def self.up
    add_column :bsc_checkpoints, :target_expenses, :decimal, :precision => 12, :scale => 4
  end

  def self.down
    remove_column :bsc_checkpoints, :target_expenses
  end
end
