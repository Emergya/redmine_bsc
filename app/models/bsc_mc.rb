class BscMc < ActiveRecord::Base
	# Varíación absoluta minima para que se registre el punto, para evitar las minimas variaciones de coste en el esfuerzo diario
	MIN_VARIATION = 50

	def self.record_date(project, start_date, end_date)
		# projects.each do |project|
		# 	get_date(project, date).save
		# end
		(start_date..end_date).each do |date|
			data = get_date(project, date)
			data.save if (data[:income].abs + data[:expenses].abs) >= MIN_VARIATION
		end
	end

	def self.get_date(project, date)
		#projects = Project.find(project).self_and_descendants.map(&:id)
		metrics = BSC::Metrics.new(project, date)
		last_entry = BscMc.where("project_id = ? AND date < ?", project, date).order("date DESC").first || BscMc.new
		total_income = metrics.total_income_scheduled
		total_expenses = metrics.total_expense_scheduled

		total_income_details = Hash.new(0.0).merge(metrics.total_income_scheduled_by_concept)
		total_expenses_details = Hash.new(0.0).merge(metrics.total_expense_scheduled_by_concept)
		old_total_income_details = Hash.new(0.0).merge(JSON.parse(last_entry.total_income_details || "{}"))
		old_total_expenses_details = Hash.new(0.0).merge(JSON.parse(last_entry.total_expenses_details || "{}"))

		mc = total_income == 0 ? nil : (100.0 * ((total_income - total_expenses) / total_income))

		BscMc.new({
			:project_id => project,
			:date => date,
			:total_income => total_income,
			:total_expenses => total_expenses,
			:income => total_income - last_entry.total_income,
			:expenses => total_expenses - last_entry.total_expenses,
			:total_income_details => total_income_details.to_json,
			:total_expenses_details => total_expenses_details.to_json,
			:income_details => (total_income_details.keys + old_total_income_details.keys).uniq.map{|k| 
					{k => total_income_details[k] - old_total_income_details[k]} 
				}.reduce(&:merge).to_json,
			:expenses_details => (total_expenses_details.keys + old_total_expenses_details.keys).uniq.map{|k| 
					{k => total_expenses_details[k] - old_total_expenses_details[k]} 
				}.reduce(&:merge).to_json,
			:mc => mc
		})
	end

	# def self.get_data(project, start_date, end_date)
	# 	#data = (end_date == Date.today) ? [get_chart_date(project, Date.today)] : []
	# 	# data += BscMc.where("project_id = ? AND date BETWEEN ? AND ?", project, start_date, end_date).order("date DESC")
	# 	data = BscMc.where("project_id = ? AND date BETWEEN ? AND ?", project, start_date, end_date).order("date DESC")
	# 	data = [get_date(project, end_date)] + data if data.detect{|d| d[:date] == end_date}.blank?
	# 	data = data + [get_date(project, start_date)] if data.detect{|d| d[:date] == start_date}.blank?

	# 	data.map{|e| 
	# 		{
	# 			:date => e.date,
	# 			:project_id => e.project_id,
	# 			:mc => e.mc,
	# 			:total_income => e.total_income,
	# 			:total_expenses => e.total_expenses,
	# 			:income_details => JSON.parse(e.income_details || "{}"),
	# 			:expenses_details => JSON.parse(e.expenses_details || "{}"),
	# 			:total_income_details => JSON.parse(e.total_income_details || "{}"),
	# 			:total_expenses_details => JSON.parse(e.total_expenses_details || "{}")
	# 		}
	# 	}
	# end



	def self.get_data(project, date)
		data = {}
		#data = (end_date == Date.today) ? [get_chart_date(project, Date.today)] : []
		# data += BscMc.where("project_id = ? AND date BETWEEN ? AND ?", project, start_date, end_date).order("date DESC")
		chart_data = BscMc.where("project_id = ? AND date <= ?", project, date).order("date DESC")
		chart_data = [get_date(project, date)] + chart_data if chart_data.detect{|d| d[:date] == date}.blank?

		data[:chart] = chart_data.map{|e| 
			{
				:date => e.date,
				:project_id => e.project_id,
				:mc => e.mc,
				:total_income => e.total_income,
				:total_expenses => e.total_expenses,
				:income_details => JSON.parse(e.income_details || "{}"),
				:expenses_details => JSON.parse(e.expenses_details || "{}"),
				:total_income_details => JSON.parse(e.total_income_details || "{}"),
				:total_expenses_details => JSON.parse(e.total_expenses_details || "{}")
			}
		}

		metrics = BSC::Metrics.new(project, date)
		data[:target_margin] = metrics.margin_target
		data[:scheduled_margin] = data[:chart].first[:mc]

		data
	end




	def self.get_header(project)
		metrics = BSC::Metrics.new(project, Date.today)
		total_income = metrics.total_income_scheduled
		total_expenses = metrics.total_expense_scheduled
		mt = metrics.margin_target
		mc = total_income == 0 ? nil : (100.0 * ((total_income - total_expenses) / total_income))

		type = (mc > mt) ? 'success' : (((mt - mc) <= 1) ? 'warn' : 'alert')
		# summary = (type == 'alert') ? "<b>#{mt-mc}</b> puntos por <b>debajo</b> del objetivo" : "<b>#{mc-mt}</b> puntos por <b>encima</b> del objetivo"

		# data = {
		# 	:type => type,
		# 	:text => "<ul><li>Margen previsto: #{mc}</li><li>Margen objetivo: #{mt}</li></ul><div class='center'>"+summary+"</div>"
		# }
		

		data = {
			:type => type,
			:mc => mc,
			:mt => mt
		}
	end
end