class BscIncomeExpense < ActiveRecord::Base
	# Number of days until planned end date for send a warning
	DAYS_WARNING = 7

	# Get income and expense content data
	def self.get_data(project)
		data = {
			:incomes => [],
			:expenses => []
		}

		projects = Array(Project.find(project).self_and_descendants).map(&:id)

		BSC::Integration.get_variable_incomes.each do |ie| 
			if ie.planned_end_date_field.present?
				(ie.issues_scheduled(projects, Date.today) - ie.issues_incurred(projects, Date.today)).each do |i|
					data[:incomes] << {
							:id => i.id,
							:title => i.subject,
							:tracker => i.tracker,
							:amount => i.amount,
							:start => i.custom_values.where(custom_field_id: ie.planned_end_date_field).first.value
						}
				end
			end
		end

		BSC::Integration.get_variable_expenses.each do |ie| 
			if ie.planned_end_date_field.present?
				(ie.issues_scheduled(projects, Date.today) - ie.issues_incurred(projects, Date.today)).each do |i|
					data[:expenses] << {
							:id => i.id,
							:title => i.subject,
							:tracker => i.tracker,
							:amount => i.amount,
							:start => i.custom_values.where(custom_field_id: ie.planned_end_date_field).first.value
						}
				end
			end
		end

		data[:incomes] = data[:incomes].sort_by{|i| i[:start]}
		data[:expenses] = data[:expenses].sort_by{|i| i[:start]}

		data
	end

	# Get income and expense header data
	def self.get_header(project)
		status = 'metric_success'
		alert = 0
		warn = 0

		projects = Array(Project.find(project).self_and_descendants).map(&:id)
		(BSC::Integration.get_variable_incomes + BSC::Integration.get_variable_expenses).each do |ie| 
			if ie.planned_end_date_field.present?
				(ie.issues_scheduled(projects, Date.today) - ie.issues_incurred(projects, Date.today)).each do |i|
					planned_date = i.custom_values.where(custom_field_id: ie.planned_end_date_field).first.value
					alert += 1 if Date.parse(planned_date) < Date.today
					warn += 1 if Date.parse(planned_date) < (Date.today + DAYS_WARNING.days)
				end
			end
		end

		if alert > 0
			status = 'metric_alert'
		elsif warn > 0
			status = 'metric_warn'
		else
			status = 'metric_success'
		end

		data = {
			:status => status,
			:number => (alert > 0) ? alert : warn
		}
	end
end