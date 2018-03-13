class AddYearToBscCheckpointEfforts < ActiveRecord::Migration
  def self.up
    add_column :bsc_checkpoint_efforts, :year, :integer, :default => 0, :null => false
    
    remove_index(:bsc_checkpoint_efforts, :name => 'index_efforts_by_checkpoint_id_and_profile_id')
    add_index :bsc_checkpoint_efforts, [:bsc_checkpoint_id, :hr_profile_id, :year], :unique => true, :name => 'index_efforts_by_checkpoint_id_and_profile_id_and_year'


    Project.all.each do |p|
    	if p.bsc_start_date.present? and p.bsc_end_date.present?
    		puts "#{p.id}"
    		start_year = p.bsc_start_date.to_date.year
    		end_year = p.bsc_end_date.to_date.year
    		years = (p.bsc_end_date.to_date.year - p.bsc_start_date.to_date.year + 1.0).to_f
    		p.bsc_checkpoints.each do |chk|
    			chk.bsc_checkpoint_efforts.each do |eff|
    				year_effort = eff.scheduled_effort.to_f / years
	    			(start_year..end_year).each do |year|
	    				new_eff_attr = eff.attributes
	    				new_eff_attr[:year] = year
	    				new_eff_attr[:id] = nil
		    			new_eff = BscCheckpointEffort.new(new_eff_attr)
		    			new_eff.scheduled_effort = year_effort
		    			new_eff.save
		    		end
		    		eff.destroy
	    		end
    		end
    	end
    end
  end

  def self.down
    remove_column :bsc_checkpoint_efforts, :year

    remove_index(:bsc_checkpoint_efforts, :name => 'index_efforts_by_checkpoint_id_and_profile_id_and_year')
    add_index :bsc_checkpoint_efforts, [:bsc_checkpoint_id, :hr_profile_id], :unique => true, :name => 'index_efforts_by_checkpoint_id_and_profile_id'
  end
end
