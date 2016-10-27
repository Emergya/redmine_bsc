class BscEffort < ActiveRecord::Base
	# Varíación absoluta minima para que se registre el punto, para evitar las minimas variaciones de coste en el esfuerzo diario
	MIN_VARIATION = 50
	# Horas de la jornada laboral
	WORKDAY_HOURS = 8

	def self.record_date(project, start_date, end_date)
		# projects.each do |project|
		# 	get_date(project, date).save
		# end
		(start_date..end_date).each do |date|
			# Save only when there is an update
			if (changes = Project.find(project).self_and_descendants.map{|p| p.last_checkpoint(date)}.select{|ckp| ckp.present? and ckp[:updated_at].to_date == date}).present?
				data = get_date(project, date)
				data.save #if data.present? #if (data[:income].abs + data[:expenses].abs) >= MIN_VARIATION
			end
		end
	end

	def self.get_date(project, date)
		#projects = Project.find(project).self_and_descendants.map(&:id)
		metrics = BSC::Metrics.new(project, date)

			BscEffort.new({
				:project_id => project,
				:date => date,
				:scheduled_hours => metrics.hhrr_hours_scheduled,
				:incurred_hours => metrics.hhrr_hours_incurred,
				:scheduled_hours_details => metrics.hhrr_hours_scheduled_by_profile.to_json,
				:incurred_hours_details => metrics.hhrr_hours_incurred_by_profile.to_json,
				:scheduled_finish_date => metrics.scheduled_finish_date
			})
		
	end

	# def self.get_data(project, start_date, end_date)
	# 	data = {
	# 		:chart => get_chart_data(project, start_date, end_date),
	# 		:table => get_table_data(project, end_date)
	# 	}
	# end

	def self.get_data(project, end_date)
		data = {
			:chart => get_chart_data(project, end_date),
			:table => get_table_data(project, end_date)
		}
	end

	# def self.get_chart_data(project, start_date, end_date)
	# 	data = BscEffort.where("project_id = ? AND date BETWEEN ? AND ?", project, start_date, end_date).order("date DESC")
	# 	data = [get_date(project, end_date)] + data if data.detect{|d| d[:date] == end_date}.blank?
	# 	data = data + [get_date(project, start_date)] if data.detect{|d| d[:date] == start_date}.blank?

	# 	data.map{|e| 
	# 		{
	# 			:date => e.date,
	# 			:project_id => e.project_id,
	# 			:scheduled_hours => e.scheduled_hours,
	# 			:incurred_hours => e.incurred_hours,
	# 			:scheduled_hours_details => JSON.parse(e.scheduled_hours_details || "{}"),
	# 			:incurred_hours_details => JSON.parse(e.incurred_hours_details || "{}")
	# 		}
	# 	}
	# end

	def self.get_chart_data(project, end_date)
		data = BscEffort.where("project_id = ? AND date <= ?", project, end_date).order("date DESC")
		data = [get_date(project, end_date)] + data if data.detect{|d| d[:date] == end_date}.blank?

		data.map{|e| 
			{
				:date => e.date,
				:project_id => e.project_id,
				:scheduled_hours => e.scheduled_hours,
				:incurred_hours => e.incurred_hours,
				:scheduled_hours_details => JSON.parse(e.scheduled_hours_details || "{}"),
				:incurred_hours_details => JSON.parse(e.incurred_hours_details || "{}"),
				:scheduled_finish_date => e.scheduled_finish_date
			}
		}
	end

	def self.get_table_data(project, date)
		metrics = BSC::Metrics.new(project, date)
		projects = Array(Project.find(project).self_and_descendants)
		last_checkpoints = projects.map{|p| p.last_checkpoint(date)}.reject{|p| p.blank?}
		profiles_name = HrProfile.all.map{|p| {p.id => p.name}}.reduce(&:merge)

		scheduled = Hash.new(0.0).merge(metrics.hhrr_hours_scheduled_by_profile)
		incurred = Hash.new(0.0).merge(metrics.hhrr_hours_incurred_by_profile)
		remaining = Hash.new(0.0).merge(metrics.hhrr_hours_remaining_by_profile)

		num_profiles = Hash.new(0.0)

		finish_date = last_checkpoints.max_by{|p| p[:scheduled_finish_date]}
		days_remaining = finish_date.present? ? (finish_date[:scheduled_finish_date] - date).to_i : 0

		last_checkpoints.map{|ckp| ckp.bsc_checkpoint_efforts}.flatten.each do |eff|
			num_profiles[eff.hr_profile_id] += eff.number
		end

		ideal_capacity = Hash.new(0.0)
		ideal_capacity_details = Hash.new("")
		data = []
		remaining.each do |profile, hours|
			#if profile.present?
				ideal_capacity[profile], ideal_capacity_details[profile] = get_ideal_capacity(remaining[profile], num_profiles[profile], days_remaining)

				data << {
					:name => profiles_name[profile],
					:number => num_profiles[profile],
					:scheduled => scheduled[profile].round(2),
					:incurred => incurred[profile].round(2),
					:remaining => remaining[profile].round(2),
					:ideal_capacity => ideal_capacity[profile].round(2),
					:ideal_capacity_details => ideal_capacity_details[profile].join(' and ')
				}
			#end
		end
		
		data << {
			:name => "Total",
			:number => num_profiles.values.sum,
			# :scheduled => metrics.hhrr_hours_scheduled.round(2),
			# :incurred => metrics.hhrr_hours_incurred.round(2),
			# :remaining => metrics.hhrr_hours_remaining.round(2),
			:scheduled => scheduled.values.sum.round(2),
			:incurred => incurred.values.sum.round(2),
			:remaining => remaining.values.sum.round(2),
			:ideal_capacity => "",
			:ideal_capacity_details => ""
		}

		data
	end

	def self.get_header(project)
		result = 0

		metrics = BSC::Metrics.new(project, Date.today)
		projects = Array(Project.find(project).self_and_descendants)
		last_checkpoints = projects.map{|p| p.last_checkpoint(Date.today)}.reject{|p| p.blank?}

		remaining = metrics.hhrr_hours_remaining_by_profile

		num_profiles = Hash.new(0.0)
		last_checkpoints.map{|ckp| ckp.bsc_checkpoint_efforts}.flatten.each do |eff|
			num_profiles[eff.hr_profile_id] += eff.number
		end

		finish_date = last_checkpoints.max_by{|p| p[:scheduled_finish_date]}
		days_remaining = finish_date.present? ? (finish_date[:scheduled_finish_date] - Date.today).to_i : 0

		remaining.keys.each do |profile|
			result += 1 if get_ideal_capacity(remaining[profile], num_profiles[profile], days_remaining)[1].present?
		end

		# data={
		# 	:type => (result > 0) ? 'alert' : 'success',
		# 	:text => (result > 0) ? "<div class='center'>Hay <b>#{result}</b> perfiles que, con la estimación actual, <b>no</b> podrán completar su dedicación</div>" : "<div class='center'>Con la estimación actual, todos los perfiles deberían poder completar su dedicación</div>"
		# }
		data={
			:type => (result > 0) ? 'alert' : 'success',
			:result => result
			# :text => (result > 0) ? "Hay <b>#{result}</b> perfiles que, con la estimación actual, <b>no</b> podrán completar su dedicación" : "Con la estimación actual, todos los perfiles deberían poder completar su dedicación"
		}
	end

	private
	# Return an array with: [value of ideal capacity, tips to fix ideal capacity]
	# effort: hash with remaining effort for profile id
	# profiles: hash with number of profiles for profile_id
	# days: number of days to the project scheduled end date
	def self.get_ideal_capacity(effort, profiles, days)
		result = 0
		details = []

		if effort == 0
			result = 0
		elsif effort < 0
			result = -1
			details << "Increase scheduled time for this profile"
			# details << "Delay the project end date" if days <= 0
		elsif effort > 0
			if profiles > 0 and days > 0
				result = effort / (profiles * days)
				details << "Add new profiles or Decrease scheduled time for this profile or Delay the project end date" if result > WORKDAY_HOURS
			else
				result = -1
				details << "Delay the project end date" if days <= 0
				details << "Add new profiles or Decrease scheduled time for this profile" if profiles <= 0
			end
		end

		[result, details]
	end


	# def get_data(date, project)
	# 	data = {}
	# 	data[:date] = date
	# 	data[:project_id] = project
	# 	date[:expenses] = {

	# 	}
	# end

	# def get_expenses(date, project)
	# end

	# def get_incomes(date, project)
	# 	IeVariableIncome.issues_scheduled(project, date).
	# end
end