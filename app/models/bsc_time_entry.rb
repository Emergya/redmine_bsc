class BscTimeEntry < ActiveRecord::Base
	# Max number of days that any user can spent without entry hours
	MAX_DAYS_ALERT = 14
	MAX_DAYS_WARNING = 7

	# Get time entry content data
	def self.get_data(project)
		data = {}
		projects = Array(Project.find(project).self_and_descendants).map(&:id)

		data[:members] = get_members_time_entry_info(projects)
		data[:profile_names] = TimeEntry.joins(:hr_profile).where("project_id IN (?)", projects).select("DISTINCT(hr_profiles.name) AS profile").map(&:profile)
		data[:profiles] = get_hours_by_month_and_profile(projects)
		
		data
	end

	# Get time entry header data
	def self.get_header(project)
		projects = Project.find(project).self_and_descendants.map(&:id)
		users = TimeEntry.where("project_id IN (?)", projects).select("user_id, MAX(spent_on) AS last_entry").group('user_id')

		warning = users.select{|u| (Date.today - u.last_entry) > MAX_DAYS_WARNING }.count
		alert = users.select{|u| (Date.today - u.last_entry) > MAX_DAYS_ALERT }.count

		data = {
			:status => (alert > 0) ? 'metric_alert' : ((warning > 0) ? 'metric_warning' : 'metric_success'),
			:number => (alert > 0) ? alert : warning
		}
	end

	private
	def self.get_hours_by_month_and_profile(projects)
		TimeEntry.joins(:hr_profile).where("project_id IN (?)", projects).
			select("hr_profiles.name AS profile, CONCAT(time_entries.tyear,'-',time_entries.tmonth) AS date, SUM(time_entries.hours) AS hours").
			group("time_entries.hr_profile_id, time_entries.tyear, time_entries.tmonth").
			order("time_entries.tyear DESC, time_entries.tmonth DESC").
			group_by{|te| te[:date]}.
			inject({}){|sum, (date, datas)| 
				sum.merge(
					{
						date => datas.map{|data| 
							{data[:profile] => data[:hours]} 
						}.reduce(&:merge) 
					}
				)
			}
	end

	def self.get_members_time_entry_info(projects)
		members = Member.where("project_id IN (?)", projects).map(&:user_id).uniq
		TimeEntry.joins(:user).where("project_id IN (?) AND user_id IN (?)", projects, members).select("time_entries.user_id AS id, users.login AS user, MAX(time_entries.spent_on) AS last_entry, SUM(time_entries.hours) AS hours").group("time_entries.user_id").order("last_entry ASC").map{|te|
			{
				:id => te[:id],
				:user => te[:user],
				:last_entry => te[:last_entry],
				:days => (Date.today - te[:last_entry]).to_i,
				:hours => te[:hours]
			}
		}
	end
end