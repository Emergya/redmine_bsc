class BscEffort < ActiveRecord::Base
	# Varíación absoluta minima para que se registre el punto, para evitar las minimas variaciones de coste en el esfuerzo diario
	MIN_VARIATION = 50
	# Horas de la jornada laboral
	WORKDAY_HOURS = 8

	# Generate historic effort data from start_date to end_date
	def self.record_date(project, start_date, end_date)
		(start_date..end_date).each do |date|
			# Save only when there is an update
			if (changes = Project.find(project).self_and_descendants.map{|p| p.last_checkpoint(date)}.select{|ckp| ckp.present? and ckp[:updated_at].to_date == date}).present?
				data = get_date(project, date)
				data.save #if data.present? #if (data[:income].abs + data[:expenses].abs) >= MIN_VARIATION
			end
		end
	end

	# Get effort data for specific date
	def self.get_date(project, date, current = false)
		#projects = Project.find(project).self_and_descendants.map(&:id)
		#metrics = @metrics || BSC::Metrics.new(project, date)
		if current
			aux_metrics = BSC::Metrics.new(project, Date.today)
			metrics = BSC::MetricsInterval.new(project, aux_metrics.real_start_date, date)
		else
			metrics = BSC::Metrics.new(project, date)
		end

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

	# Get effort content data
	def self.get_data(project, date_option)
		#metrics = @metrics || BSC::Metrics.new(project, date)
		if date_option == '0'
			end_date = Date.today
			metrics = @metrics || BSC::Metrics.new(project, end_date)
			start_date = metrics.real_start_date
		else
			start_date = Date.parse(date_option+"-01-01")
			end_date = Date.parse(date_option+"-12-31")
			metrics = BSC::MetricsInterval.new(project, start_date, end_date)
		end

		data = {
			:chart => get_chart_data(project, start_date, end_date),
			:table => get_table_data(project, end_date, metrics),
			:scheduled_finish_date => metrics.scheduled_finish_date
		}
	end

	# Get chart effort data
	def self.get_chart_data(project, start_date, end_date)
		#data = BscEffort.where("project_id = ? AND date <= ?", project, end_date).order("date DESC")
		data = BscEffort.where("project_id = ? AND date BETWEEN ? AND ?", project, start_date, end_date).order("date DESC")
		data = [get_date(project, end_date, true)] + data if data.detect{|d| d[:date] == end_date}.blank?

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

	# Get table effort data
	def self.get_table_data(project, date, metrics)
		#metrics = @metrics || BSC::Metrics.new(project, date)
		profiles_name = BSC::Integration.get_profiles(metrics.real_start_date).map{|p| {p.id => p.name}}.reduce(&:merge)

		start_date = metrics.scheduled_start_date.present? ? [metrics.scheduled_start_date, Date.today].max : Date.today
		days_remaining = get_days_remaining(start_date, metrics.scheduled_finish_date)

		scheduled = Hash.new(0.0).merge(metrics.hhrr_hours_scheduled_by_profile)
		incurred = Hash.new(0.0).merge(metrics.hhrr_hours_incurred_by_profile)
		remaining = Hash.new(0.0).merge(metrics.hhrr_hours_remaining_by_profile)
		num_profiles = get_profiles_number(project, date)

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
					:ideal_capacity_details => ideal_capacity_details[profile]
				}
			#end
		end
		
		data << {
			:name => "Total",
			:number => num_profiles.values.sum,
			:scheduled => scheduled.values.sum.round(2),
			:incurred => incurred.values.sum.round(2),
			:remaining => remaining.values.sum.round(2),
			:ideal_capacity => "-",
			:ideal_capacity_details => ""
		}

		data
	end

	# Get header effort data
	def self.get_header(project)
		result = 0
		metrics = @metrics || BSC::Metrics.new(project, Date.today)

		remaining = metrics.hhrr_hours_remaining_by_profile
		num_profiles = get_profiles_number(project, Date.today)

		start_date = metrics.scheduled_start_date.present? ? [metrics.scheduled_start_date, Date.today].max : Date.today
		days_remaining = get_days_remaining(start_date, metrics.scheduled_finish_date)

		remaining.keys.each do |profile|
			result += 1 if get_ideal_capacity(remaining[profile], num_profiles[profile], days_remaining)[1].present?
		end

		data={
			:status => (result > 0) ? 'metric_alert' : 'metric_success',
			:result => result
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

		if effort.round(2) == 0
			result = 0
		elsif effort.round(2) < 0
			result = -1
			details << l(:"bsc.text_increase_scheduled_time")
		elsif effort.round(2) > 0
			if profiles > 0 and days > 0
				result = effort / (profiles * days)
				details << [l(:"bsc.text_add_profiles"), l(:"bsc.text_decrease_scheduled_time"), l(:"bsc.text_delay_project_end_date")].join(l(:"bsc.text_or"))  if result > WORKDAY_HOURS
			else
				result = -1
				details << l(:"bsc.text_delay_project_end_date") if days <= 0
				details << [l(:"bsc.text_add_profiles"), l(:"bsc.text_decrease_scheduled_time")].join(l(:"bsc.text_or")) if profiles <= 0
			end
		end

		[result, details.join(l(:"bsc.text_and"))]
	end

	def self.get_profiles_number(project, date)
		projects = Array(Project.find(project).self_and_descendants)
		last_checkpoints = projects.map{|p| p.last_checkpoint(date)}.reject{|p| p.blank?}

		num_profiles = Hash.new(0.0)
		last_checkpoints.map{|ckp| ckp.bsc_checkpoint_efforts}.flatten.each do |eff|
			num_profiles[eff.hr_profile_id] += eff.number
		end
		num_profiles
	end

	def self.get_days_remaining(start_date, finish_date)
		if finish_date.present?
			total_days = (finish_date - start_date).to_i
			weeks = total_days/7
			days_offset = total_days - (weeks*7)
			weekdays = weeks*2
			case start_date.wday
			when 0
				weekdays += 1
			when 6
				weekdays += (days_offset > 1) ? 2 : 1
			else
				weekdays += [[(start_date.wday + days_offset) - 5, 0].max, 2].min
			end

			return (total_days - weekdays)
		else
			return 0
		end
	end
end