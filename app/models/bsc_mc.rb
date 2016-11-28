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
	def self.get_date(project, date)
		#projects = Project.find(project).self_and_descendants.map(&:id)
		metrics = @metrics || BSC::Metrics.new(project, date)
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
	def self.get_data(project, date)
		data = {}

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

		metrics = @metrics || BSC::Metrics.new(project, date)
		data[:target_margin] = metrics.margin_target
		data[:scheduled_margin] = data[:chart].first[:mc]

		data
	end

	# Get header mc data
	def self.get_header(project)
		metrics = @metrics || BSC::Metrics.new(project, Date.today)
		total_income = metrics.total_income_scheduled
		total_expenses = metrics.total_expense_scheduled
		mt = metrics.margin_target || 0.0
		mc = total_income == 0 ? 0.0 : (100.0 * ((total_income - total_expenses) / total_income))

		status = (mc > (mt + 1)) ? 'metric_success' : (((mt - mc).abs <= 1) ? 'metric_warning' : 'metric_alert')

		data = {
			:status => status,
			:mc => mc,
			:mt => mt
		}
	end
end