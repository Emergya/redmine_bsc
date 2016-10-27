class BscTimeEntry < ActiveRecord::Base
	# Max number of days that any user can spent without entry hours
	MAX_DAYS = 14

	def self.get_data(project)
		data = {
			:members => [],
			:profiles => [],
			:profile_names => []
		}
		projects = Array(Project.find(project).self_and_descendants).map(&:id)

		data[:members] = TimeEntry.joins(:user).where("project_id IN (?)", projects).select("time_entries.user_id AS id, users.login AS user, MAX(time_entries.spent_on) AS last_entry, SUM(time_entries.hours) AS hours").group("time_entries.user_id").order("last_entry ASC").map{|te|
			{
				:id => te[:id],
				:user => te[:user],
				:last_entry => te[:last_entry],
				:days => (Date.today - te[:last_entry]).to_i,
				:hours => te[:hours]
			}
		}


		# first_year = TimeEntry.joins(:user).where("project_id IN (?)", projects).min(tyear)
		# first_month = TimeEntry.joins(:user).where("project_id IN (?)", projects).min(tmonth)
		# last_year = TimeEntry.joins(:user).where("project_id IN (?)", projects).max(tyear)
		# last_month = TimeEntry.joins(:user).where("project_id IN (?)", projects).max(tmonth)

		# (first_year..last_year).each do |year|
		# 	start_month = (year == first_year) ? first_month : 1
		# 	end_month = (year == last_year) ? last_month : 1

		# 	(start_month..end_month).each do |month|
		# 		TimeEntry.joins(:hr_profile).where("project_id IN (?)", projects).select("hr_profiles.name AS profile, CONCAT(time_entries.tyear,'-',time_entries.tmonth) AS date, SUM(time_entries.hours) AS hours").group("time_entries.hr_profile_id")
		# 	end
		# end

		data[:profile_names] = TimeEntry.joins(:hr_profile).where("project_id IN (?)", projects).select("DISTINCT(hr_profiles.name) AS profile").map(&:profile)

		data[:profiles] = TimeEntry.joins(:hr_profile).where("project_id IN (?)", projects).
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
		

		data
	end
end