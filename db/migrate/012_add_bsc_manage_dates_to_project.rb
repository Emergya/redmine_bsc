class AddBscManageDatesToProject < ActiveRecord::Migration
  def self.up
    add_column :projects, :bsc_manage_dates, :boolean, :default => false
  end

  def self.down
    remove_column :projects, :bsc_manage_dates
  end
end
