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
							:start => i.custom_values.where(custom_field_id: ie.planned_end_date_field).first.value,
							:type => 'income'
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
							:start => i.custom_values.where(custom_field_id: ie.planned_end_date_field).first.value,
							:type => 'expense'
						}
				end
			end
		end

		data[:incomes] = data[:incomes].sort_by{|i| i[:start]}
		data[:expenses] = data[:expenses].sort_by{|i| i[:start]}

		data[:calendar] = []
		(data[:incomes]+data[:expenses]).group_by{|e| e[:start]}.each do |date, elements|
			data[:calendar] << {
				:start => date,
				:content => "<span class='incomes'>"+"&#9679"*elements.count{|e| e[:type] == 'income'}+"</span><span class='expenses'>"+"&#9679"*elements.count{|e| e[:type] == 'expense'}+"</span>",
				:tooltip => "<b>"+date+"</b><table class='tooltip_calendar_income_expenses'>"+elements.select{|e| e[:type] == 'income'}.map{|e| "<tr><td class='point incomes'>&#9679</td><td>"+e[:title]+"</td></tr>"}.join('')+elements.select{|e| e[:type] == 'expense'}.map{|e| "<tr><td class='point expenses'>&#9679</td><td>"+e[:title]+"</td></tr>"}.join('')+"</table>"
			}
		end


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