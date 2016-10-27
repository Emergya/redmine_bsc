class CreateBscEfforts < ActiveRecord::Migration
  def self.up
    create_table :bsc_efforts do |t|
      t.integer :project_id, :null => false
      t.date :date, :null => false
      t.decimal :scheduled_hours, :default => 0.0000, :precision => 12, :scale => 4
      t.decimal :incurred_hours, :default => 0.0000, :precision => 12, :scale => 4
      t.text :scheduled_hours_details
      t.text :incurred_hours_details
      t.date :scheduled_finish_date
      t.timestamps
    end
    add_index :bsc_efforts, [:project_id, :date], :unique => true
    add_index :bsc_efforts, :project_id
  end

  def self.down
    drop_table :bsc_efforts
  end
end