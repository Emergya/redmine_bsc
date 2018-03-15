namespace :bsc do
	task :change_profiles => :environment do
		projects = Project.active
		new_profile = {1 => 21, 2 => 19, 3 => 18, 4 => 16, 5 => 14, 6 => 11, 7 => 23, 8 => 10}

		projects.each do |project|
			puts "#{project.identifier}"
			metric = BSC::Metrics.new(project.id)
			last_checkpoint = project.last_checkpoint
			if last_checkpoint.present?
				puts "#{last_checkpoint.inspect}"
				efforts = last_checkpoint.bsc_checkpoint_efforts
				incurred = metric.hhrr_hours_incurred_by_profile
				efforts.each do |effort|
					puts "#{effort.inspect}"
					remaining_effort = effort.scheduled_effort - incurred[effort.hr_profile_id]
					if remaining_effort > 0
						effort.scheduled_effort = incurred[effort.hr_profile_id]
						BscCheckpointEffort.create({bsc_checkpoint_id: last_checkpoint.id, hr_profile_id: new_profile[effort.hr_profile_id], scheduled_effort: remaining_effort, number: effort.number})
						effort.save
					end
				end
			end
		end

	end

end
