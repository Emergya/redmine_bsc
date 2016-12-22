namespace :bsc do
	task :daily_record => :environment do
		# projects = Project.active.select{|p| p.enabled_modules.map(&:name).include?('bscplugin')}.select{|p| p.bsc_info.present?}.map(&:id)
		projects = Project.active.map(&:id)

		BscMc.where("project_id IN (?) AND date = ?", projects, Date.yesterday).destroy_all
		BscEffort.where("project_id IN (?) AND date = ?", projects, Date.yesterday).destroy_all

		projects.each do |project|
            ##
			puts "Enable module"
			Project.find(project).enable_module!('bscplugin')
			##
			BscMc.record_date(project, Date.yesterday, Date.yesterday)
			BscEffort.record_date(project, Date.yesterday, Date.yesterday)
		end
	end

	task :update_records, [:start_date, :end_date, :projects] => :environment do |t, args|
		# projects = args[:projects] || Project.active.select{|p| p.enabled_modules.map(&:name).include?('bscplugin')}.select{|p| p.bsc_info.present?}.map(&:id)
		projects = Project.active.map(&:id)

		puts "Deleting old records"
		start_date = args[:start_date] || Project.minimum(:created_on).to_date
		end_date = args[:end_date] || Date.yesterday
		BscMc.where("project_id IN (?) AND date BETWEEN ? AND ?", projects, start_date, end_date).destroy_all
		BscEffort.where("project_id IN (?) AND date BETWEEN ? AND ?", projects, start_date, end_date).destroy_all

		projects.each do |project|
			##
			puts "Enable module"
			Project.find(project).enable_module!('bscplugin')
			##
			puts "Recording data for project with id = #{project}"
			start_date = args[:start_date] || Project.find(project).created_on.to_date
			end_date = args[:end_date] || Date.yesterday
			puts "Recording MC data"
			BscMc.record_date(project, start_date, end_date)
			puts "Recording Effort data"
			BscEffort.record_date(project, start_date, end_date)
		end
	end
end