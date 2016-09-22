class CreateBscProjectInfos < ActiveRecord::Migration
  def self.up
    create_table :bsc_project_infos do |t|
      t.integer :project_id, :null => false
      t.date :actual_start_date, :null => true, :default => nil
      t.date :scheduled_start_date, :null => false
      t.date :scheduled_finish_date, :null => false
      t.integer :scheduled_qa_meetings, :null => false
      t.timestamps
    end
    add_index :bsc_project_infos, :project_id, :unique => true
  end

  def self.down
    drop_table :bsc_project_infos
  end
end