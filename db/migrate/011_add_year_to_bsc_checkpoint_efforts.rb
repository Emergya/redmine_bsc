class AddYearToBscCheckpointEfforts < ActiveRecord::Migration
  def self.up
    add_column :bsc_checkpoint_efforts, :year, :integer, :default => 0, :null => false
    
    remove_index(:bsc_checkpoint_efforts, :name => 'index_efforts_by_checkpoint_id_and_profile_id')
    add_index :bsc_checkpoint_efforts, [:bsc_checkpoint_id, :hr_profile_id, :year], :unique => true, :name => 'index_efforts_by_checkpoint_id_and_profile_id_and_year'

    Project.all.each do |p|
        if p.bsc_start_date.present? and p.bsc_end_date.present?
            puts "#{p.id}"
            start_date = p.real_start_date.present? ? p.real_start_date : p.bsc_start_date
            start_year = start_date.to_date.year

            p.bsc_checkpoints.each do |chk|
                end_year = chk.scheduled_finish_date.to_date.year
                future_days = (p.bsc_end_date.to_date - Date.today).to_f + 1.0
                chk.bsc_checkpoint_efforts.each do |eff|
                    incurred = Hash.new(0.0)
                    (start_year..end_year).each do |year|
                        new_eff_attr = eff.attributes
                        new_eff_attr[:year] = year
                        new_eff_attr[:id] = nil
                        new_eff = BscCheckpointEffort.new(new_eff_attr)
                        if Date.today.year > year
                            if year == end_year
                                new_eff.scheduled_effort = eff[:scheduled_effort] - incurred[new_eff[:hr_profile_id]]
                            else
                                myear = BSC::MetricsInterval.new(p.id, "#{year}-01-01".to_date, "#{year}-12-31".to_date)
                                new_eff.scheduled_effort = myear.hhrr_hours_incurred_by_profile[new_eff[:hr_profile_id]]
                                incurred[new_eff[:hr_profile_id]] += new_eff.scheduled_effort
                            end
                        elsif Date.today.year == year
                            if year == end_year 
                                new_eff.scheduled_effort = (eff[:scheduled_effort] - incurred[new_eff[:hr_profile_id]])
                            else
                                myear = BSC::MetricsInterval.new(p.id, "#{year}-01-01".to_date, "#{year}-12-31".to_date)
                                new_eff.scheduled_effort = myear.hhrr_hours_incurred_by_profile[new_eff[:hr_profile_id]]
                                incurred[new_eff[:hr_profile_id]] += new_eff.scheduled_effort
                                if future_days > 0
                                    new_eff.scheduled_effort += ((["#{year}-12-31".to_date, p.bsc_end_date].min - ["#{year}-01-01".to_date, p.bsc_start_date.to_date, Date.today].max) * ((eff[:scheduled_effort] - incurred[new_eff[:hr_profile_id]]) / future_days))
                                end
                            end
                        else
                            new_eff.scheduled_effort = ((["#{year}-12-31".to_date, p.bsc_end_date].min - ["#{year}-01-01".to_date, p.bsc_start_date.to_date].max) * ((eff[:scheduled_effort] - incurred[new_eff[:hr_profile_id]]) / future_days))
                        end
                        new_eff.save
                    end
                    eff.destroy
                end
            end
        end
    end
  end

  def self.down
    Project.all.each do |p|
        if p.bsc_start_date.present? and p.bsc_end_date.present?
            puts "#{p.id}"
            last_year = p.bsc_checkpoints.last.bsc_checkpoint_efforts.maximum(:year)
            p.bsc_checkpoints.each do |chk|
                chk.bsc_checkpoint_efforts.where(year: last_year).each do |eff|
                    eff.scheduled_effort = chk.bsc_checkpoint_efforts.where(hr_profile_id: eff.hr_profile_id).sum(:scheduled_effort)
                    eff.save
                end
                chk.bsc_checkpoint_efforts.where("year <> ?", last_year).destroy_all
            end
        end
    end
    

    remove_index(:bsc_checkpoint_efforts, :name => 'index_efforts_by_checkpoint_id_and_profile_id_and_year')
    add_index :bsc_checkpoint_efforts, [:bsc_checkpoint_id, :hr_profile_id], :unique => true, :name => 'index_efforts_by_checkpoint_id_and_profile_id'
  
    remove_column :bsc_checkpoint_efforts, :year
  end
end
