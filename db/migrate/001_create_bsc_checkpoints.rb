class CreateBscCheckpoints < ActiveRecord::Migration
  def self.up
    create_table :bsc_checkpoints do |t|
      t.integer :project_id, :null => false
      t.integer :author_id, :null => false
      t.text :description
      t.date :checkpoint_date, :null => false
      t.date :scheduled_finish_date, :null => false
      t.integer :held_qa_meetings, :null => false
      t.boolean :base_line, :null => false, :default => 0
      t.integer :target_margin, :null => false
      t.timestamps
    end
    add_index :bsc_checkpoints, :project_id

    create_table :bsc_checkpoint_efforts do |t|
      t.references :bsc_checkpoint, :null => false
      t.references :hr_profile, :null => false
      t.float :scheduled_effort, :null => false, :default => 0
      t.timestamps
    end
    add_index :bsc_checkpoint_efforts, [:bsc_checkpoint_id, :hr_profile_id], :unique => true
  end

  def self.down
    drop_table :bsc_checkpoints
    drop_table :bsc_checkpoint_efforts
  end
end