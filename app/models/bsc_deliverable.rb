class BscDeliverable < ActiveRecord::Base
	# Number of days until planned end date for send a warning
	DAYS_WARNING = 7

	def self.get_data(project)
		data = {:deliverables => []}

		projects = Array(Project.find(project).self_and_descendants).map(&:id)

		data[:deliverables] = get_deliverables_issues(projects).map{|i|
			{
				:id => i[:id],
				:title => i[:subject],
				:status => i[:status],
				:start => i[:delivery_date],
				:assigned_to => i.assigned_to.to_s,
				:done_ratio => i[:done_ratio]
			}
		}

		data[:calendar] = []
		data[:deliverables].group_by{|e| e[:start]}.each do |date, elements|
			data[:calendar] << {
				:start => date,
				:content => "<span class='deliverables'>"+"&#9679"*elements.count+"</span>",
				:tooltip => "<b>"+date+"</b><table class='tooltip_calendar_deliverables'>"+elements.map{|e| "<tr><td class='point deliverables'>&#9679</td><td>"+e[:title]+"</td></tr>"}.join('')+"</table>"
			}
		end

		data
	end

	def self.get_header(project)
		projects = Array(Project.find(project).self_and_descendants).map(&:id)
		issues = get_deliverables_issues(projects)

		# Get number of deliveries in alert and warning
		alert = issues.select{|i| Date.parse(i.delivery_date) < Date.today}.count
		warning = issues.select{|i| Date.parse(i.delivery_date) < (Date.today + DAYS_WARNING.days)}.count

		data = {
			:status => (alert > 0) ? 'metric_alert' : ((warning > 0) ? 'metric_warning' : 'metric_success'),
			:number => (alert > 0) ? alert : warning
		}
	end

	private
	def self.get_deliverables_issues(projects)
		if Setting.plugin_redmine_bsc['deliverables_tracker'].present? and Setting.plugin_redmine_bsc['delivery_date'].present? and Setting.plugin_redmine_bsc['delivery_status'].present?
			Tracker.find(Setting.plugin_redmine_bsc['deliverables_tracker']).issues.
				includes(:assigned_to).
				joins(:status).
				joins("LEFT JOIN custom_values AS cv ON cv.customized_type = 'Issue' AND cv.customized_id = issues.id AND cv.custom_field_id = "+Setting.plugin_redmine_bsc[:delivery_date]).
				where("issues.project_id IN (?) AND issues.status_id <> ?", projects, Setting.plugin_redmine_bsc[:delivery_status]).
				select("issues.id, issues.subject, issue_statuses.name AS status, cv.value AS delivery_date, issues.assigned_to_id, issues.done_ratio").
				order("delivery_date ASC")
		else
			[]
		end
	end
end