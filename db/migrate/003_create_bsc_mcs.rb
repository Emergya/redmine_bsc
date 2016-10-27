class CreateBscMcs < ActiveRecord::Migration
  def self.up
    create_table :bsc_mcs do |t|
      t.integer :project_id, :null => false
      t.date :date, :null => false
      t.decimal :total_income, :default => 0.0000, :precision => 12, :scale => 4
      t.decimal :total_expenses, :default => 0.0000, :precision => 12, :scale => 4
      t.decimal :income, :default => 0.0000, :precision => 12, :scale => 4
      t.decimal :expenses, :default => 0.0000, :precision => 12, :scale => 4
      t.text :total_income_details
      t.text :total_expenses_details
      t.text :income_details
      t.text :expenses_details
      t.float :mc, :default => 0.0
      t.timestamps
    end
    add_index :bsc_mcs, [:project_id, :date], :unique => true
    add_index :bsc_mcs, :project_id
  end

  def self.down
    drop_table :bsc_mcs
  end
end