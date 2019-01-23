class BscBalance < ActiveRecord::Base
	# Días hacía atrás que se revisan diariamente para actualizar la información de los puntos de balance
	BALANCE_UPDATE_DAYS = 20
	# Porcentaje de variación mínimo de cambios en los ingresos y gastos absolutos respecto al máximo entre los ingresos y gastos estimados, a partir del cual se toma un nuevo punto
	BALANCE_MIN_VARIATION_PERCENT = 3
	# Número máximo de días sin generar puntos
	BALANCE_MAX_DAYS = 0

	# Balance point first time save
	def initial_save
		self.original_income_details = self.income_details
		self.original_expense_details = self.expense_details
		self.save
	end

	# Generate historic balance data from start_date to end_date
	def self.record_date(project, start_date, end_date)
		# days without generate historic balance points
		last_point = BscBalance.where("project_id = ? AND date <= ?", project, start_date).order('date DESC')
		days = last_point.present? ? (start_date - last_point.first.date).to_i : 0
		
		(start_date..end_date).each do |date|
			days += 1
			data = get_date(project, date)

			metrics = BSC::Metrics.new(project, date)
			base = [metrics.total_income_scheduled, metrics.total_expense_scheduled].max
			min_variation = (base * BALANCE_MIN_VARIATION_PERCENT / 100)

			if (BALANCE_MAX_DAYS > 0 and days >= BALANCE_MAX_DAYS) or (data[:income_changes].abs + data[:expense_changes].abs) >= min_variation
				data.initial_save
				days = 0
			end
		end
	end

	# Update balance points to current data values
	def self.update_record_date(project, start_date, end_date)
		balance_points = BscBalance.where("project_id = ? AND date BETWEEN ? AND ?", project, start_date, end_date)
		
		balance_points.each do |b|
			data = get_date(project, b.date, true)
			if b.incomes != data.incomes or b.expenses != data.expenses
				attributes = data.attributes.reject{|k,v| v.nil?}
				b.update_attributes(attributes)
			end
		end
	end

	# Get balance data for specific date
	def self.get_date(project, date, current = false)
		if current
			aux_metrics = BSC::Metrics.new(project, Date.today)
			metrics = BSC::MetricsInterval.new(project, aux_metrics.real_start_date, date)
		else
			metrics = BSC::Metrics.new(project, date)
		end

		last_entry = BscBalance.where("project_id = ? AND date < ?", project, date).order("date DESC").first || BscBalance.new
		incomes = metrics.total_income_incurred
		expenses = metrics.total_expense_incurred

		income_details = Hash.new(0.0).merge(metrics.total_income_incurred_by_concept)
		expense_details = Hash.new(0.0).merge(metrics.total_expense_incurred_by_concept)
		old_income_details = Hash.new(0.0).merge(JSON.parse(last_entry.income_details || "{}"))
		old_expense_details = Hash.new(0.0).merge(JSON.parse(last_entry.expense_details || "{}"))

		# Get income difference details
		income_detail_changes = ((income_details.keys + old_income_details.keys).uniq.map{|k| 
					{k => income_details[k] - old_income_details[k]} 
				}.reduce(&:merge) ||
				{})
		# Get expense difference details
		expense_detail_changes = ((expense_details.keys + old_expense_details.keys).uniq.map{|k| 
					{k => expense_details[k] - old_expense_details[k]} 
				}.reduce(&:merge) ||
				{})

		BscBalance.new({
			:project_id => project,
			:date => date,
			:incomes => incomes,
			:expenses => expenses,
			:income_changes => incomes - last_entry.incomes,
			:expense_changes => expenses - last_entry.expenses,
			:income_details => income_details.to_json,
			:expense_details => expense_details.to_json,
			:income_detail_changes => income_detail_changes.to_json,
			:expense_detail_changes => expense_detail_changes.to_json
		})
	end

	# Get balance content data
	def self.get_data(project, date_option)
		if date_option == '0'
			end_date = Date.today
			metrics = @metrics || BSC::Metrics.new(project, end_date)
			start_date = metrics.real_start_date
		else
			start_date = Date.parse(date_option+"-01-01")
			end_date = Date.parse(date_option+"-12-31")
			metrics = BSC::MetricsInterval.new(project, start_date, end_date)
		end

		{
			:table => get_table_data(metrics),
			:chart => get_chart_data(project, start_date, end_date, metrics),
			:scheduled_margin => metrics.scheduled_margin
		}
	end

	# Get balance table data
	def self.get_table_data(metrics)
		income_variable_scheduled = metrics.variable_income_scheduled_by_tracker
		income_variable_incurred = metrics.variable_income_incurred_by_tracker

		expense_variable_scheduled = metrics.variable_expense_scheduled_by_tracker
		expense_variable_incurred = metrics.variable_expense_incurred_by_tracker
		expense_fixed_scheduled = metrics.fixed_expense_scheduled_by_tracker
		expense_fixed_incurred = metrics.fixed_expense_incurred_by_tracker

		incomes = {}
		income_variable_scheduled.each do |ie, scheduled|
			incurred = (income_variable_incurred.present? and income_variable_incurred[ie].present?) ? income_variable_incurred[ie] : 0
			remaining = scheduled.to_f - incurred.to_f
			incomes[ie] = {:scheduled => scheduled, :incurred => incurred, :remaining => remaining}
		end

		expenses = {'RRHH' => {:scheduled => metrics.hhrr_cost_scheduled, :incurred => metrics.hhrr_cost_incurred, :remaining => metrics.hhrr_cost_remaining}}
		expense_variable_scheduled.each do |ie, scheduled|
			incurred = (expense_variable_incurred.present? and expense_variable_incurred[ie].present?) ? expense_variable_incurred[ie] : 0
			remaining = scheduled.to_f - incurred.to_f
			expenses[ie] = {:scheduled => scheduled, :incurred => incurred, :remaining => remaining}
		end
		expense_fixed_scheduled.each do |ie, scheduled|
			incurred = (expense_fixed_incurred.present? and expense_fixed_incurred[ie].present?) ? expense_fixed_incurred[ie] : 0
			remaining = scheduled.to_f - incurred.to_f
			expenses[ie] = {:scheduled => scheduled, :incurred => incurred, :remaining => remaining}
		end

		{
			:total_income => {:scheduled => metrics.total_income_scheduled, :incurred => metrics.total_income_incurred, :remaining => metrics.total_income_remaining},
			:total_expense => {:scheduled => metrics.total_expense_scheduled, :incurred => metrics.total_expense_incurred, :remaining => metrics.total_expense_remaining},
			:incomes => incomes,
			:expenses => expenses
		}
	end

	# Get balance chart data
	def self.get_chart_data(project, start_date, end_date, metrics)
		# Obtenemos los datos que había en el momento justo anterior al inicio del intervalo
		if start_date > metrics.real_start_date
			metric_before = BSC::MetricsInterval.new(project, metrics.real_start_date, start_date-1.day)
			# Redondeamos porque, de lo contrario, al restar el offset al valor del punto, se crea un número negativo pequeño (< 0.0001) que hace que se muestre en la gráfica el eje Y negativo
			offset_incomes = metric_before.total_income_incurred.round(4)
			offset_expenses = metric_before.total_expense_incurred.round(4)
			offset_income_details = Hash.new(0.0).merge(metric_before.total_income_incurred_by_concept)
			offset_expense_details = Hash.new(0.0).merge(metric_before.total_expense_incurred_by_concept)
		else
			offset_incomes = 0.0
			offset_expenses = 0.0
			offset_income_details = Hash.new(0.0)
			offset_expense_details = Hash.new(0.0)
		end

		# Obtenemos los puntos del intervalo
		data = BscBalance.where("project_id = ? AND date BETWEEN ? AND ?", project, start_date, end_date).order("date DESC")

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
			{
				:date => e.date,
				:project_id => e.project_id,
				:incomes => e.incomes-offset_incomes,
				:expenses => e.expenses-offset_expenses,
				:income_details => e.income_details.present? ? JSON.parse(e.income_details).inject({}){|h,(k,v)| h[k] = v - offset_income_details[k]; h} : offset_income_details,
				:expense_details => e.expense_details.present? ? JSON.parse(e.expense_details).inject({}){|h,(k,v)| h[k] = v - offset_expense_details[k]; h} : offset_expense_details,
				:income_detail_changes => JSON.parse(e.income_detail_changes || "{}"),
				:expense_detail_changes => JSON.parse(e.expense_detail_changes || "{}")
			}
		}
	end

	# Get balance header data
	def self.get_header(project)
		metrics = @metrics || BSC::Metrics.new(project, Date.today)

		result = metrics.total_income_incurred - metrics.total_expense_incurred

		data = {
			:status => (result > 0) ? 'metric_success' : 'metric_alert',
			:result => result
		}
	end	

	# Get warning for exceeded incurred expenses
	def self.get_exceeded_incurred_expenses(project)
		metrics = @metrics || BSC::Metrics.new(project, Date.today)

		start_year = metrics.real_start_date.year
		current_year = Date.today.year
		expense_exceeded = {}
		partial_status = {}

		(start_year..current_year).each do |myear|
			partial_start_date = Date.parse(myear.to_s+"-01-01")
			partial_end_date = Date.parse(myear.to_s+"-12-31")
			aux_metrics = BSC::MetricsInterval.new(project, partial_start_date, partial_end_date)

			expense_exceeded[myear] = aux_metrics.total_expense_incurred - (aux_metrics.hhrr_cost_scheduled_checkpoint + aux_metrics.variable_expense_scheduled + aux_metrics.fixed_expense_scheduled)
			partial_status[myear] = (expense_exceeded[myear] <= 0) ? 'metric_success' : 'metric_warning'

		end

		status = partial_status.has_value?('metric_warning') ? 'metric_warning' : 'metric_success'

		data = {
			:expense_exceeded => expense_exceeded,
			:status => status,
			:partial_status => partial_status,
			:start_year => start_year,
			:current_year => current_year
		}
	end
end