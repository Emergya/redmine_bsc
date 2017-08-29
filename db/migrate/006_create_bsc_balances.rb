class CreateBscBalances < ActiveRecord::Migration
  def self.up
    create_table :bsc_balances do |t|
      t.integer :project_id, :null => false
      t.date :date, :null => false
      t.decimal :incomes, :default => 0.0000, :precision => 12, :scale => 4
      t.decimal :expenses, :default => 0.0000, :precision => 12, :scale => 4
      t.decimal :income_changes, :default => 0.0000, :precision => 12, :scale => 4
      t.decimal :expense_changes, :default => 0.0000, :precision => 12, :scale => 4
      t.text :income_details
      t.text :expense_details
      t.text :income_detail_changes
      t.text :expense_detail_changes
      t.timestamps
    end
    add_index :bsc_balances, [:project_id, :date], :unique => true
    add_index :bsc_balances, :project_id
  end

  def self.down
    drop_table :bsc_balances
  end
end