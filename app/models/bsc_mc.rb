class BscMc < ActiveRecord::Base
	# Varíación absoluta minima para que se registre el punto, para evitar las minimas variaciones de coste en el esfuerzo diario
	MIN_VARIATION = 50
	MC_MIN_VARIATION = 0.3

	# Generate historic mc data from start_date to end_date
	def self.record_date(project, start_date, end_date)
		(start_date..end_date).each do |date|
			data = get_date(project, date)

			income_details = JSON.parse(data[:income_details])
			expense_details = JSON.parse(data[:expenses_details]).reject{|k,v| k == 'RRHH'}
			if income_details.merge(expense_details).detect{|k,v| v.abs > 0}
				data.save
			elsif (data[:income].abs + data[:expenses].abs) > [(MC_MIN_VARIATION * data[:mc].to_f.abs), MIN_VARIATION].max
				data.save
			end
		end
	end

	# Get mc data for specific date
	def self.get_date(project, date, current = false)
		if current
			aux_metrics = BSC::Metrics.new(project, Date.today)
			metrics = BSC::MetricsInterval.new(project, aux_metrics.real_start_date, date)
		else
			metrics = BSC::Metrics.new(project, date)
		end

		last_entry = BscMc.where("project_id = ? AND date < ?", project, date).order("date DESC").first || BscMc.new
		total_income = metrics.total_income_scheduled
		total_expenses = metrics.total_expense_scheduled

		total_income_details = Hash.new(0.0).merge(metrics.total_income_scheduled_by_concept)
		total_expenses_details = Hash.new(0.0).merge(metrics.total_expense_scheduled_by_concept)
		old_total_income_details = Hash.new(0.0).merge(JSON.parse(last_entry.total_income_details || "{}"))
		old_total_expenses_details = Hash.new(0.0).merge(JSON.parse(last_entry.total_expenses_details || "{}"))

		# Get income difference details
		income_details = ((total_income_details.keys + old_total_income_details.keys).uniq.map{|k| 
					{k => total_income_details[k] - old_total_income_details[k]} 
				}.reduce(&:merge) ||
				{})
		# Get expense difference details
		expenses_details = ((total_expenses_details.keys + old_total_expenses_details.keys).uniq.map{|k| 
					{k => total_expenses_details[k] - old_total_expenses_details[k]} 
				}.reduce(&:merge) ||
				{})

		mc = total_income == 0 ? 0.0 : (100.0 * ((total_income - total_expenses) / total_income))

		BscMc.new({
			:project_id => project,
			:date => date,
			:total_income => total_income,
			:total_expenses => total_expenses,
			:income => total_income - last_entry.total_income,
			:expenses => total_expenses - last_entry.total_expenses,
			:total_income_details => total_income_details.to_json,
			:total_expenses_details => total_expenses_details.to_json,
			:income_details => income_details.to_json,
			:expenses_details => expenses_details.to_json,
			:mc => mc
		})
	end

	# Get mc content data
	def self.get_data(project, date_option)
		if date_option.blank? or date_option == '0'
			end_date = Date.today
			metrics = @metrics || BSC::Metrics.new(project, end_date)
			start_date = metrics.real_start_date
		else
			start_date = Date.parse(date_option+"-01-01")
			end_date = Date.parse(date_option+"-12-31")
			metrics = BSC::MetricsInterval.new(project, start_date, end_date)
		end

		{
			#:table => get_table_data(metrics),
			:chart => get_chart_data(project, start_date, end_date, metrics),
			:target_margin => metrics.margin_target,
			:scheduled_margin => metrics.scheduled_margin,
			:target_expenses => metrics.expenses_target,
			:scheduled_expenses => metrics.total_expense_scheduled
		}
	end



		# data = {}

		# chart_data = BscMc.where("project_id = ? AND date <= ?", project, date).order("date DESC")
		# chart_data = [get_date(project, date, true)] + chart_data if chart_data.detect{|d| d[:date] == date}.blank?

		# data[:chart] = chart_data.map{|e| 
		# 	{
		# 		:date => e.date,
		# 		:project_id => e.project_id,
		# 		:mc => e.mc,
		# 		:total_income => e.total_income,
		# 		:total_expenses => e.total_expenses,
		# 		:income_details => JSON.parse(e.income_details || "{}"),
		# 		:expenses_details => JSON.parse(e.expenses_details || "{}"),
		# 		:total_income_details => JSON.parse(e.total_income_details || "{}"),
		# 		:total_expenses_details => JSON.parse(e.total_expenses_details || "{}")
		# 	}
		# }

		# metrics = @metrics || BSC::Metrics.new(project, date)
		# data[:target_margin] = metrics.margin_target
		# data[:scheduled_margin] = data[:chart].first[:mc]
		# data[:target_expenses] = metrics.expenses_target
		# data[:scheduled_expenses] = data[:chart].first[:total_expenses]

		# data


	def self.get_chart_data(project, start_date, end_date, metrics)
		# Obtenemos los datos que había en el momento justo anterior al inicio del intervalo
		if start_date > metrics.real_start_date
			metric_before = BSC::MetricsInterval.new(project, metrics.real_start_date, start_date-1.day)
			# Redondeamos porque, de lo contrario, al restar el offset al valor del punto, se crea un número negativo pequeño (< 0.0001) que hace que se muestre en la gráfica el eje Y negativo
			#offset_mc = metric_before.scheduled_margin
			offset_total_income = metric_before.total_income_scheduled.round(4)
			offset_total_expenses = metric_before.total_expense_scheduled.round(4)
			offset_total_income_details = Hash.new(0.0).merge(metric_before.total_income_scheduled_by_concept)
			offset_total_expenses_details = Hash.new(0.0).merge(metric_before.total_expense_scheduled_by_concept)
		else
			#offset_mc = 0.0
			offset_total_income = 0.0
			offset_total_expenses = 0.0
			offset_total_income_details = Hash.new(0.0)
			offset_total_expenses_details = Hash.new(0.0)
		end

		# Obtenemos los puntos del intervalo
		data = BscMc.where("project_id = ? AND date BETWEEN ? AND ?", project, start_date, end_date).order("date DESC")

		# Calculamos los datos del primer día si no existen
		if !data.map(&:date).include?(start_date)
			data += [get_date(project, start_date, true)]
		end

		# Calculamos los datos del último día si no existen
		if !data.map(&:date).include?(end_date)
			data += [get_date(project, end_date, true)]
		end

		data = data.sort_by{|b| b[:date]}
		data.map{|e| 
			# Redondear cuando 0.0
			total_income = (e.total_income-offset_total_income).round(2)
			total_expenses = (e.total_expenses-offset_total_expenses).round(2)
			{
				:date => e.date,
				:project_id => e.project_id,
				:mc => total_income == 0 ? 0.0 : (100.0 * ((total_income - total_expenses) / total_income)), #e.mc,
				:total_income => total_income,
				:total_expenses => total_expenses,
				:total_income_details => e.total_income_details.present? ? JSON.parse(e.total_income_details).inject({}){|h,(k,v)| h[k] = v - offset_total_income_details[k]; h} : offset_total_income_details,
				:total_expenses_details => e.total_expenses_details.present? ? JSON.parse(e.total_expenses_details).inject({}){|h,(k,v)| h[k] = v - offset_total_expenses_details[k]; h} : offset_total_expenses_details,
				:income_details => JSON.parse(e.income_details || "{}"),
				:expenses_details => JSON.parse(e.expenses_details || "{}")
			}
		}
	end


	# Get header mc data
	def self.get_header(project)
		metrics = @metrics || BSC::Metrics.new(project, Date.today)
		total_income = metrics.total_income_scheduled
		total_expenses = metrics.total_expense_scheduled
		mt = metrics.margin_target || 0.0
		mc = total_income == 0 ? 0.0 : (100.0 * ((total_income - total_expenses) / total_income))

		ct = metrics.expenses_target || 0.0
		cc = total_expenses

		status = (mc > (mt + 1) and ct >= cc) ? 'metric_success' : (((ct < cc) or (mc < (mt - 1))) ? 'metric_alert' : 'metric_warning')

		data = {
			:status => status,
			:mc => mc,
			:mt => mt,
			:cc => cc,
			:ct => ct
		}
	end
end