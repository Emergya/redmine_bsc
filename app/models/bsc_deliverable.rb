class BscDeliverable < ActiveRecord::Base
	# Number of days until planned end date for send a warning
	DAYS_WARNING = 7

	def self.get_data(project)
		data = {:deliverables => []}

		projects = Array(Project.find(project).self_and_descendants).map(&:id)

		if Setting.plugin_redmine_bsc['deliverables_tracker'].present? and Setting.plugin_redmine_bsc['delivery_date'].present? and Setting.plugin_redmine_bsc['delivery_status'].present?
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
		end

		data
	end

	def self.get_header(project)
		projects = Array(Project.find(project).self_and_descendants).map(&:id)
		issues = get_deliverables_issues(project)

		# Get number of deliveries in alert and warning
		alert = issues.select{|i| Date.parse(i.delivery_date) < Date.today}.count
		warning = issues.select{|i| Date.parse(i.delivery_date) < (Date.today + DAYS_WARNING.days)}.count

		data = {
			:type => (alert > 0) ? 'alert' : ((warning > 0) ? 'warn' : 'success'),
			:number => (alert > 0) ? alert : warning
		}
	end

	private
	def self.get_deliverables_issues(projects)
		Tracker.find(Setting.plugin_redmine_bsc['deliverables_tracker']).issues.
			includes(:assigned_to).
			joins(:status).
			joins("LEFT JOIN custom_values AS cv ON cv.customized_type = 'Issue' AND cv.customized_id = issues.id AND cv.custom_field_id = "+Setting.plugin_redmine_bsc[:delivery_date]).
			where("issues.project_id IN (?) AND issues.status_id <> ?", projects, Setting.plugin_redmine_bsc[:delivery_status]).
			select("issues.id, issues.subject, issue_statuses.name AS status, cv.value AS delivery_date, issues.assigned_to_id, issues.done_ratio").
			order("delivery_date ASC")
	end
end