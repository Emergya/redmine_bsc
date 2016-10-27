class BscIncomeExpense < ActiveRecord::Base
	# Number of days until planned end date for send a warning
	DAYS_WARNING = 7

	def self.get_data(project)
		data = {
			:incomes => [],
			:expenses => []
		}
		projects = Array(Project.find(project).self_and_descendants).map(&:id)
		IeVariableIncome.all.each do |ie| 
			if ie.planned_end_date_field.present?
				ie.issues_scheduled(projects, Date.today).each do |i|
					data[:incomes] << {
							:id => i.id,
							:title => i.subject,
							:type => i.tracker.name,
							:amount => i.amount,
							:start => i.custom_values.where(custom_field_id: ie.planned_end_date_field).first.value
						}
				end
			end
		end

		IeVariableExpense.all.each do |ie| 
			if ie.planned_end_date_field.present?
				ie.issues_scheduled(projects, Date.today).each do |i|
					data[:expenses] << {
							:id => i.id,
							:title => i.subject,
							:type => i.tracker.name,
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

	def self.get_header(project)
		type = 'success'
		text = "No hay pagos ni cobros en la próxima semana"
		alert = 0
		warn = 0

		projects = Array(Project.find(project).self_and_descendants).map(&:id)
		(IeVariableIncome.all + IeVariableExpense.all).each do |ie| 
			if ie.planned_end_date_field.present?
				ie.issues_scheduled(projects, Date.today).each do |i|
					planned_date = i.custom_values.where(custom_field_id: ie.planned_end_date_field).first.value
					alert += 1 if Date.parse(planned_date) < Date.today
					warn += 1 if Date.parse(planned_date) < (Date.today + DAYS_WARNING.days)
				end
			end
		end

		if alert > 0
			type = 'alert'
		elsif warn > 0
			type = 'warn'
		else
			type = 'success'
		end

		# data = {
		# 	:type => type,
		# 	:text => "<div class='center'>"+text+"</div>"
		# }
		data = {
			:type => type,
			:number => (alert > 0) ? alert : warn
		}
	end
end