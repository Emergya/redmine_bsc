namespace :bsc do
	task :change_profiles_1 => :environment do
		projects = Project.active
		new_profile = {1 => 21, 2 => 19, 3 => 18, 4 => 16, 5 => 14, 6 => 11, 7 => 23, 8 => 10}

		projects.each do |project|
			puts "#{project.identifier}"
			metric = BSC::Metrics.new(project.id)
			metric_2017 = BSC::MetricsInterval.new(project.id, metric.real_start_date, "2017-12-31".to_date)
			last_checkpoint = project.last_checkpoint
			if last_checkpoint.present?
				puts "#{last_checkpoint.inspect}"
				efforts = last_checkpoint.bsc_checkpoint_efforts
				incurred = metric.hhrr_hours_incurred_by_profile
				incurred_2017 = metric_2017.hhrr_hours_incurred_by_profile
				efforts.each do |effort|
					puts "#{effort.inspect}"
					remaining_effort = effort.scheduled_effort - incurred[effort.hr_profile_id]
					effort.scheduled_effort = incurred_2017[effort.hr_profile_id]
					# if remaining_effort > 0
					BscCheckpointEffort.create({bsc_checkpoint_id: last_checkpoint.id, hr_profile_id: new_profile[effort.hr_profile_id], scheduled_effort: remaining_effort, number: effort.number})
					# end
					effort.save
				end
			end
		end

	end


	task :change_profiles_2 => :environment do
		projects = Project.active

		projects.each do |project|
			puts "#{project.identifier}"
			metric = BSC::Metrics.new(project.id)
			metric_2018 = BSC::MetricsInterval.new(project.id, "2018-01-01".to_date, metric.real_finish_date)
			last_checkpoint = project.last_checkpoint
			if last_checkpoint.present?
				puts "#{last_checkpoint.inspect}"
				incurred_2018 = metric_2018.hhrr_hours_incurred_by_profile

				incurred_2018.each do |profile, hours|
					puts "#{profile}: #{hours}"
					if (effort = last_checkpoint.bsc_checkpoint_efforts.where(hr_profile_id: profile)).present?
						effort.first.scheduled_effort += hours
						effort.first.save
					else
						BscCheckpointEffort.create({bsc_checkpoint_id: last_checkpoint.id, hr_profile_id: profile, scheduled_effort: hours, number: 0.0})
					end
				end
			end
		end

	end

end
