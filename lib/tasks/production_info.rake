require 'csv'
CF_SERVICIO_ID = 102
CF_LOCALIZACION_ID = 166
CF_UNEGOCIO_ID = 275 
CF_RESP_PRODUCCION = 276
CF_RESP_NEGOCIO = 277
CF_SUBUNIDADNEG_ID = 288
CF_CLIENTE_FINAL_ID = 289

VARIABLE_EXPENSES = ['Providers', 'Other expenses', 'Subsistence allowance', 'Other expenses HHRR']
VARIABLE_INCOMES = ['Clients', 'Other incomes']

ARCHIVADOS_PROJECT_ID = 82
CF_ESTADO_ID = 120
CF_EXPEDIENTE_ID = 26
CF_INICO_GARANTIA_ID = 264
CF_FIN_GARANTIA_ID = 265

T_OTHER_INCOMES = 65
T_OTHER_EXPENSES = 66
T_OTHER_EXPENSES_RRHH = 68

CF_IMPORTE = 152
CF_TIPO_INGRESO = 273
CF_TIPO_GASTO = 274
CF_TIPO_GASTO_RRHH = 282
CF_FECHA_FACTURACION = 153

namespace :bsc2 do
	task :production_info => :environment do
		user_profiles
		time_entries
		checkpoints
		profiles_cost
		time_entries_years
		generate_projects_data
		time_entries_last_year
		get_projects_with_cost_overrun_last_year
		time_entries_daily
		time_entries_last_months
		user_profile_cost_last_months
	end

	def user_profiles
		headers = ["login", "name", "rol", "start_date", "end_date", "activo"]
		results = [headers]

		users = User.joins(:profiles)
		users.each do |user|
			profiles = user.profiles

			if profiles.present?
				profiles.each do |profile|
					result = []

					result << user.login
					result << user.name
					result << profile.profile.name
					result << profile.start_date
					result << profile.end_date
					result << (user.active? ? "Sí" : "No")
				
					results << result
				end
			else
				results << [user.login, user.name, nil, nil, nil]
			end
		end

		generate_csv("user_profiles", results)
	end

	def time_entries
		year = Date.today.year
		headers = ["user", "project_name", "project_identifier", "mercado", "servicio", "unidad de negocio", "responsable prod", "responsable negocio", "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sept", "oct", "nov", "dec", "linea negocio"]

		results = [headers]
		# users = User.active
		users = User.find(TimeEntry.where(tyear: year).distinct(:user_id).map(&:user_id))

		users.each do |u|
			projects = Project.find(TimeEntry.where(user_id: u.id, tyear: year).distinct(:project_id).map(&:project_id)) #u.projects.active

			projects.each do |p|
				te = TimeEntry.where(user_id: u.id, project_id: p.id, tyear: year)

				if te.present?
					result = []

					result << u.login
					result << p.name
					result << p.identifier
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_LOCALIZACION_ID).first) ? (cf.present? ? cf.value : '') : 0
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_SERVICIO_ID).first) ? (cf.present? ? cf.value : '') : 0
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_UNEGOCIO_ID).first) ? (cf.present? ? cf.value : '') : 0
					cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_RESP_PRODUCCION).first
					if cf.present? and cf.value.present?
						result << User.find(cf.value).login
					else
						result << ''
					end
					cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_RESP_NEGOCIO).first
					if cf.present? and cf.value.present?
						result << User.find(cf.value).login
					else
						result << ''
					end
					(1..12).each do |i|
						result << te.where(tmonth: i).sum(:hours)
					end

					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_SUBUNIDADNEG_ID).first) ? (cf.present? ? cf.value : '') : 0

					results << result
				end
			end
		end

		generate_csv("time_entries_current_year", results)
	end

	def checkpoints
		headers = ["checkpoint_id", "project", "date"]

		HrProfile.all.each do |profile|
			headers << profile.name
		end

		headers << "base_line"
		headers << "author"

		results = [headers]
		projects = Project.active

		projects.each do |project|
			checkpoints = project.bsc_checkpoints.order('checkpoint_date DESC, created_at DESC')

			checkpoints.each do |checkpoint|
				result = []

				result << checkpoint.id
				result << project.identifier
				result << checkpoint.checkpoint_date

				efforts = Hash.new(0.0).merge(checkpoint.bsc_checkpoint_efforts.map{|eff| [eff.hr_profile_id, eff.scheduled_effort]}.to_h)
				HrProfile.all.each do |profile|
					result << efforts[profile.id]
				end

				result << (checkpoint.base_line ? "Sí" : "No")
				result << checkpoint.author.login

				results << result
			end
		end

		generate_csv("checkpoints", results)
	end

	def profiles_cost
		headers = ["year", "profile", "cost"]

		results = [headers]
		profiles = HrProfilesCost.all

		profiles.each do |profile|
			result = []
			result << profile.year
			result << profile.profile.name
			result << profile.hourly_cost
			results << result
		end

		generate_csv("profiles_cost", results)
	end

	def time_entries_years
		start_year = TimeEntry.where("project_id IN (?)", Project.active.map(&:id)).minimum(:tyear)
		end_year = Date.today.year
		headers = ["user", "project_name", "project_identifier", "mercado", "servicio", "unidad de negocio", "responsable prod", "responsable negocio", "horas"]

		(start_year..end_year).each do |year|
			headers << year
		end

		results = [headers]
		# users = User.active
		users = User.all

		users.each do |u|
			# projects = u.projects.active
			projects = Project.find(TimeEntry.where(user_id: u.id).distinct(:project_id).map(&:project_id))

			projects.each do |p|
				te = TimeEntry.where(user_id: u.id, project_id: p.id)

				if te.present?
					result = []

					result << u.login
					result << p.name
					result << p.identifier
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_LOCALIZACION_ID).first) ? (cf.present? ? cf.value : '') : 0
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_SERVICIO_ID).first) ? (cf.present? ? cf.value : '') : 0
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_UNEGOCIO_ID).first) ? (cf.present? ? cf.value : '') : 0
					cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_RESP_PRODUCCION).first
					if cf.present? and cf.value.present?
						result << User.find(cf.value).login
					else
						result << ''
					end
					cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_RESP_NEGOCIO).first
					if cf.present? and cf.value.present?
						result << User.find(cf.value).login
					else
						result << ''
					end
					result << te.sum(:hours)
					(start_year..end_year).each do |year|
						result << te.where(tyear: year).sum(:hours)
					end

					results << result
				end
			end
		end

		generate_csv("time_entries_all_years", results)
	end

	def generate_projects_data
		projects = Project.active.reject{|p| p.ancestors.detect{|a| a.bsc_end_date.present?}}
		headers = []
		results = [[]]

		projects.each do |p|
			puts "#{p.identifier}"
			maux = BSC::MetricsInterval.new(p.id, Date.parse(Date.today.year.to_s+"-01-01"), Date.parse(Date.today.year.to_s+"-12-31"), {:descendants => false})
			include_descendants = (p.bsc_end_date.present? and p.parent_id != ARCHIVADOS_PROJECT_ID)

			start_year = maux.real_start_date.year
			end_year = maux.real_finish_date.year

			(["total"]+Array(start_year..end_year)).each do |year|
				if year == "total"
					metrics = BSC::Metrics.new(p.id, Date.today, {:descendants => include_descendants})
				else
					metrics = BSC::MetricsInterval.new(p.id, Date.parse(year.to_s+"-01-01"), Date.parse(year.to_s+"-12-31"), {:descendants => include_descendants})
				end

				# if maux.total_income_scheduled != 0 or maux.variable_expense_scheduled != 0 or maux.hhrr_cost_incurred != 0 or maux.fixed_expense_scheduled != 0 or (start_year <= Date.today.year and end_year >= Date.today.year)
					puts "Atributos del proyecto"
					headers = []
					result = []
					headers << "id"
					result << p.id
					headers << "name"
					result << p.name
					headers << "identifier"
					result << p.identifier
					headers << "año"
					result << year
					puts "Campos del proyecto"
					# Campos Estado, Servicio, Localización geográfica y Unidad de negocio
					headers << "estado"
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_ESTADO_ID).first) ? (cf.present? ? cf.value : '') : 0
					headers << "localizacion"
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_LOCALIZACION_ID).first) ? (cf.present? ? cf.value : '') : 0
					headers << "servicio"
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_SERVICIO_ID).first) ? (cf.present? ? cf.value : '') : 0
					headers << "unidad de negocio"
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_UNEGOCIO_ID).first) ? (cf.present? ? cf.value : '') : 0
					headers << "subunidad"
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_SUBUNIDADNEG_ID).first) ? (cf.present? ? cf.value : '') : 0
					headers << "responsable producción"
					cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_RESP_PRODUCCION).first
					if cf.present? and cf.value.present?
						result << User.find(cf.value).login
					else
						result << ''
					end
					headers << "responsable negocio"
					cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_RESP_NEGOCIO).first
					if cf.present? and cf.value.present?
						result << User.find(cf.value).login
					else
						result << ''
					end
					headers << "ultimo punto de control"
					result << (p.last_checkpoint ? p.last_checkpoint.checkpoint_date : "-")
					headers << "fecha de fin"
					result << maux.scheduled_finish_date
					puts "MC"
					headers << "mc incurrido"
					result << metrics.total_income_incurred - metrics.total_expense_incurred
					headers << "mc"
					result << metrics.total_income_scheduled - metrics.total_expense_scheduled
					headers << "%mc"
					result << metrics.scheduled_margin
					headers << "mc objetivo"
					result << metrics.margin_target
					headers << "coste objetivo"
					result << metrics.expenses_target
					headers << "ingresos objetivo"
					result << metrics.incomes_target
					puts "Scheduled"
					headers << "bpo estimado"
					result << metrics.fixed_expense_scheduled
					headers << "esfuerzo estimado"
					result << metrics.hhrr_cost_scheduled
					VARIABLE_EXPENSES.each do |expense|
						headers << expense.downcase+" estimado"
						result << metrics.variable_expense_scheduled_by_tracker[expense]
					end
					VARIABLE_INCOMES.each do |income|
						headers << income.downcase+" estimado"
						result << metrics.variable_income_scheduled_by_tracker[income]
					end

					puts "Incurred"
					headers << "bpo incurrido"
					result << metrics.fixed_expense_incurred
					headers << "esfuerzo incurrido"
					result << metrics.hhrr_cost_incurred
					VARIABLE_EXPENSES.each do |expense|
						headers << expense.downcase+" incurrido"
						result << metrics.variable_expense_incurred_by_tracker[expense]
					end
					VARIABLE_INCOMES.each do |income|
						headers << income.downcase+" incurrido"
						result << metrics.variable_income_incurred_by_tracker[income]
					end

					puts "Remaining"
					headers << "bpo restantes"
					result << metrics.fixed_expense_remaining
					headers << "esfuerzo restantes"
					result << metrics.hhrr_cost_remaining
					VARIABLE_EXPENSES.each do |expense|
						headers << expense.downcase+" restante"
						result << (metrics.variable_expense_scheduled_by_tracker[expense] || 0.0) - (metrics.variable_expense_incurred_by_tracker[expense] || 0.0)
					end
					VARIABLE_INCOMES.each do |income|
						headers << income.downcase+" restante"
						result << (metrics.variable_income_scheduled_by_tracker[income] || 0.0) - (metrics.variable_income_incurred_by_tracker[income] || 0.0)
					end

					headers << "%consecución (puntos de control)"
					result << ((p.last_checkpoint.present? and p.last_checkpoint.achievement_percentage.present?) ? p.last_checkpoint.achievement_percentage : "-")
					headers << "%consecución (avance peticiones)"
					result << ((year == 'total') ? p.issues.map(&:done_ratio).sum/p.issues.count.to_f : '-')
					headers << "expediente"
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_EXPEDIENTE_ID).first) ? (cf.present? ? cf.value : '') : 0
					headers << "inicio garantía"
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_INICO_GARANTIA_ID).first) ? (cf.present? ? cf.value : '') : 0
					headers << "fin garantía"
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_FIN_GARANTIA_ID).first) ? (cf.present? ? cf.value : '') : 0
					headers << "fecha comienzo planificada"
					result << metrics.scheduled_start_date
					headers << "fecha comienzo real"
					result << metrics.real_start_date
					

					metric_projects = [p.id] + (include_descendants.present? ? p.descendants.active.map(&:id) : [])
                    headers << "Ajustes contables de ingresos estimados"
                    if year=="total"
                            scheduled_incomes_ajustes = BSC::Integration.get_variable_incomes.find{|e| e.tracker_id==T_OTHER_INCOMES}.issues_scheduled(metric_projects, Date.today).sum{|i| i.amount.to_f}
                    else
                            scheduled_incomes_ajustes = BSC::Integration.get_variable_incomes.find{|e| e.tracker_id==T_OTHER_INCOMES}.issues_scheduled_interval(metric_projects, "#{year}-01-01".to_date, "#{year}-12-31".to_date).sum{|i| i.amount.to_f}
                    end
                    result << scheduled_incomes_ajustes
                    headers << "Ajustes contables de gastos estimados"
                    if year=="total"
                            scheduled_expenses_ajustes = BSC::Integration.get_variable_expenses.find{|e| e.tracker_id==T_OTHER_EXPENSES}.issues_scheduled(metric_projects, Date.today).sum{|i| i.amount.to_f}
                    else
                            scheduled_expenses_ajustes = BSC::Integration.get_variable_expenses.find{|e| e.tracker_id==T_OTHER_EXPENSES}.issues_scheduled_interval(metric_projects, "#{year}-01-01".to_date, "#{year}-12-31".to_date).sum{|i| i.amount.to_f}
                    end
                    result << scheduled_expenses_ajustes

					headers << "Ajustes contables de ingresos incurridos"
                    if year=="total"
                            incurred_incomes_ajustes = BSC::Integration.get_variable_incomes.find{|e| e.tracker_id==T_OTHER_INCOMES}.issues_incurred(metric_projects, Date.today).sum{|i| i.amount.to_f}
                    else
                            incurred_incomes_ajustes = BSC::Integration.get_variable_incomes.find{|e| e.tracker_id==T_OTHER_INCOMES}.issues_incurred_interval(metric_projects, "#{year}-01-01".to_date, "#{year}-12-31".to_date).sum{|i| i.amount.to_f}
                    end
                    result << incurred_incomes_ajustes
                    headers << "Ajustes contables de gastos incurridos"
                    if year=="total"
                            incurred_expenses_ajustes = BSC::Integration.get_variable_expenses.find{|e| e.tracker_id==T_OTHER_EXPENSES}.issues_incurred(metric_projects, Date.today).sum{|i| i.amount.to_f}
                    else
                            incurred_expenses_ajustes = BSC::Integration.get_variable_expenses.find{|e| e.tracker_id==T_OTHER_EXPENSES}.issues_incurred_interval(metric_projects, "#{year}-01-01".to_date, "#{year}-12-31".to_date).sum{|i| i.amount.to_f}
                    end
                    result << incurred_expenses_ajustes

					headers << "Ajustes contables de ingresos restantes"
                    result << scheduled_incomes_ajustes - incurred_incomes_ajustes
                    headers << "Ajustes contables de gastos restantes"
                    result << scheduled_expenses_ajustes - incurred_expenses_ajustes
                    headers << "Padre ID"
                    result << p.parent_id
                    headers << "Indemnización"
                    if year=="total"
                    	compensations = Issue.joins("LEFT JOIN custom_values AS type ON type.customized_type = 'Issue' AND type.customized_id = issues.id AND type.custom_field_id = #{CF_TIPO_GASTO_RRHH}").joins("LEFT JOIN custom_values AS amount ON amount.customized_type = 'Issue' AND amount.customized_id = issues.id AND amount.custom_field_id = #{CF_IMPORTE}").where("issues.tracker_id = ? AND issues.project_id IN (?) AND type.value = ?", T_OTHER_EXPENSES_RRHH, metric_projects,'Indemnización').sum('amount.value')
                    else
                    	compensations = Issue.joins("LEFT JOIN custom_values AS type ON type.customized_type = 'Issue' AND type.customized_id = issues.id AND type.custom_field_id = #{CF_TIPO_GASTO_RRHH}").joins("LEFT JOIN custom_values AS amount ON amount.customized_type = 'Issue' AND amount.customized_id = issues.id AND amount.custom_field_id = #{CF_IMPORTE}").joins("LEFT JOIN custom_values AS billing_date ON billing_date.customized_type = 'Issue' AND billing_date.customized_id = issues.id AND billing_date.custom_field_id = #{CF_FECHA_FACTURACION}").where("issues.tracker_id = ? AND issues.project_id IN (?) AND type.value = ? AND billing_date.value BETWEEN ? AND ?", T_OTHER_EXPENSES_RRHH, metric_projects,'Indemnización', "#{year}-01-01", "#{year}-12-31").sum('amount.value')
                    end
                    result << compensations
                    headers << "Ajuste interanual ingresos diciembre"
                    if year=="total"
                    	december_incomes_adjustments = Issue.joins("LEFT JOIN custom_values AS type ON type.customized_type = 'Issue' AND type.customized_id = issues.id AND type.custom_field_id = #{CF_TIPO_INGRESO}").joins("LEFT JOIN custom_values AS amount ON amount.customized_type = 'Issue' AND amount.customized_id = issues.id AND amount.custom_field_id = #{CF_IMPORTE}").joins("LEFT JOIN custom_values AS billing_date ON billing_date.customized_type = 'Issue' AND billing_date.customized_id = issues.id AND billing_date.custom_field_id = #{CF_FECHA_FACTURACION}").where("issues.tracker_id = ? AND issues.project_id IN (?) AND type.value = ? AND MONTH(billing_date.value) = ?", T_OTHER_INCOMES, metric_projects,'Ajuste Interanual', 12).sum('amount.value')
                    else
                    	december_incomes_adjustments = Issue.joins("LEFT JOIN custom_values AS type ON type.customized_type = 'Issue' AND type.customized_id = issues.id AND type.custom_field_id = #{CF_TIPO_INGRESO}").joins("LEFT JOIN custom_values AS amount ON amount.customized_type = 'Issue' AND amount.customized_id = issues.id AND amount.custom_field_id = #{CF_IMPORTE}").joins("LEFT JOIN custom_values AS billing_date ON billing_date.customized_type = 'Issue' AND billing_date.customized_id = issues.id AND billing_date.custom_field_id = #{CF_FECHA_FACTURACION}").where("issues.tracker_id = ? AND issues.project_id IN (?) AND type.value = ? AND billing_date.value BETWEEN ? AND ?", T_OTHER_INCOMES, metric_projects,'Ajuste Interanual', "#{year}-12-01", "#{year}-12-31").sum('amount.value')
                    end
                    result << december_incomes_adjustments
                    headers << "Ajuste interanual gastos diciembre"
                    if year=="total"
                    	december_expenses_adjustments = Issue.joins("LEFT JOIN custom_values AS type ON type.customized_type = 'Issue' AND type.customized_id = issues.id AND type.custom_field_id = #{CF_TIPO_GASTO}").joins("LEFT JOIN custom_values AS amount ON amount.customized_type = 'Issue' AND amount.customized_id = issues.id AND amount.custom_field_id = #{CF_IMPORTE}").joins("LEFT JOIN custom_values AS billing_date ON billing_date.customized_type = 'Issue' AND billing_date.customized_id = issues.id AND billing_date.custom_field_id = #{CF_FECHA_FACTURACION}").where("issues.tracker_id = ? AND issues.project_id IN (?) AND type.value = ? AND MONTH(billing_date.value) = ?", T_OTHER_EXPENSES, metric_projects,'Ajuste Interanual', 12).sum('amount.value')
                    else
                    	december_expenses_adjustments = Issue.joins("LEFT JOIN custom_values AS type ON type.customized_type = 'Issue' AND type.customized_id = issues.id AND type.custom_field_id = #{CF_TIPO_GASTO}").joins("LEFT JOIN custom_values AS amount ON amount.customized_type = 'Issue' AND amount.customized_id = issues.id AND amount.custom_field_id = #{CF_IMPORTE}").joins("LEFT JOIN custom_values AS billing_date ON billing_date.customized_type = 'Issue' AND billing_date.customized_id = issues.id AND billing_date.custom_field_id = #{CF_FECHA_FACTURACION}").where("issues.tracker_id = ? AND issues.project_id IN (?) AND type.value = ? AND billing_date.value BETWEEN ? AND ?", T_OTHER_EXPENSES, metric_projects,'Ajuste Interanual', "#{year}-12-01", "#{year}-12-31").sum('amount.value')
                    end
                    result << december_expenses_adjustments
                    headers << "Ajuste interanual ingresos enero"
                    if year=="total"
                    	january_incomes_adjustments = Issue.joins("LEFT JOIN custom_values AS type ON type.customized_type = 'Issue' AND type.customized_id = issues.id AND type.custom_field_id = #{CF_TIPO_INGRESO}").joins("LEFT JOIN custom_values AS amount ON amount.customized_type = 'Issue' AND amount.customized_id = issues.id AND amount.custom_field_id = #{CF_IMPORTE}").joins("LEFT JOIN custom_values AS billing_date ON billing_date.customized_type = 'Issue' AND billing_date.customized_id = issues.id AND billing_date.custom_field_id = #{CF_FECHA_FACTURACION}").where("issues.tracker_id = ? AND issues.project_id IN (?) AND type.value = ? AND MONTH(billing_date.value) = ?", T_OTHER_INCOMES, metric_projects,'Ajuste Interanual', 1).sum('amount.value')
                    else
                    	january_incomes_adjustments = Issue.joins("LEFT JOIN custom_values AS type ON type.customized_type = 'Issue' AND type.customized_id = issues.id AND type.custom_field_id = #{CF_TIPO_INGRESO}").joins("LEFT JOIN custom_values AS amount ON amount.customized_type = 'Issue' AND amount.customized_id = issues.id AND amount.custom_field_id = #{CF_IMPORTE}").joins("LEFT JOIN custom_values AS billing_date ON billing_date.customized_type = 'Issue' AND billing_date.customized_id = issues.id AND billing_date.custom_field_id = #{CF_FECHA_FACTURACION}").where("issues.tracker_id = ? AND issues.project_id IN (?) AND type.value = ? AND billing_date.value BETWEEN ? AND ?", T_OTHER_INCOMES, metric_projects,'Ajuste Interanual', "#{year}-01-01", "#{year}-01-31").sum('amount.value')
                    end
                    result << january_incomes_adjustments
                    headers << "Ajuste interanual gastos enero"
                    if year=="total"
                    	january_expenses_adjustments = Issue.joins("LEFT JOIN custom_values AS type ON type.customized_type = 'Issue' AND type.customized_id = issues.id AND type.custom_field_id = #{CF_TIPO_GASTO}").joins("LEFT JOIN custom_values AS amount ON amount.customized_type = 'Issue' AND amount.customized_id = issues.id AND amount.custom_field_id = #{CF_IMPORTE}").joins("LEFT JOIN custom_values AS billing_date ON billing_date.customized_type = 'Issue' AND billing_date.customized_id = issues.id AND billing_date.custom_field_id = #{CF_FECHA_FACTURACION}").where("issues.tracker_id = ? AND issues.project_id IN (?) AND type.value = ? AND MONTH(billing_date.value) = ?", T_OTHER_EXPENSES, metric_projects,'Ajuste Interanual', 1).sum('amount.value')
                    else
                    	january_expenses_adjustments = Issue.joins("LEFT JOIN custom_values AS type ON type.customized_type = 'Issue' AND type.customized_id = issues.id AND type.custom_field_id = #{CF_TIPO_GASTO}").joins("LEFT JOIN custom_values AS amount ON amount.customized_type = 'Issue' AND amount.customized_id = issues.id AND amount.custom_field_id = #{CF_IMPORTE}").joins("LEFT JOIN custom_values AS billing_date ON billing_date.customized_type = 'Issue' AND billing_date.customized_id = issues.id AND billing_date.custom_field_id = #{CF_FECHA_FACTURACION}").where("issues.tracker_id = ? AND issues.project_id IN (?) AND type.value = ? AND billing_date.value BETWEEN ? AND ?", T_OTHER_EXPENSES, metric_projects,'Ajuste Interanual', "#{year}-01-01", "#{year}-01-31").sum('amount.value')
                    end
                    result << january_expenses_adjustments
                    headers << "Indemnización restante"
                    if year=="total"
                    	remaining_compensations = Issue.joins("LEFT JOIN custom_values AS type ON type.customized_type = 'Issue' AND type.customized_id = issues.id AND type.custom_field_id = #{CF_TIPO_GASTO_RRHH}").joins("LEFT JOIN custom_values AS amount ON amount.customized_type = 'Issue' AND amount.customized_id = issues.id AND amount.custom_field_id = #{CF_IMPORTE}").where("issues.tracker_id = ? AND issues.project_id IN (?) AND issues.status_id = 1 AND type.value = ?", T_OTHER_EXPENSES_RRHH, metric_projects,'Indemnización').sum('amount.value')
                    else
                    	remaining_compensations = Issue.joins("LEFT JOIN custom_values AS type ON type.customized_type = 'Issue' AND type.customized_id = issues.id AND type.custom_field_id = #{CF_TIPO_GASTO_RRHH}").joins("LEFT JOIN custom_values AS amount ON amount.customized_type = 'Issue' AND amount.customized_id = issues.id AND amount.custom_field_id = #{CF_IMPORTE}").joins("LEFT JOIN custom_values AS billing_date ON billing_date.customized_type = 'Issue' AND billing_date.customized_id = issues.id AND billing_date.custom_field_id = #{CF_FECHA_FACTURACION}").where("issues.tracker_id = ? AND issues.project_id IN (?) AND issues.status_id = 1 AND type.value = ? AND billing_date.value BETWEEN ? AND ?", T_OTHER_EXPENSES_RRHH, metric_projects,'Indemnización', "#{year}-01-01", "#{year}-12-31").sum('amount.value')
                    end
                    result << remaining_compensations
                    headers << "Cliente Final"
                    result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_CLIENTE_FINAL_ID).first) ? (cf.present? ? cf.value : '') : 0

					# p.versions.map{|v| v.completed_percent.to_f * v.issues_count.to_f / 100.0}.sum / p.issues.count.to_f)
					results << result
				# end
				results[0] = headers
			end
		end

		generate_csv("projects_data", results)
	end

	def time_entries_last_year
		year = Date.today.year-1
		headers = ["user", "project_name", "project_identifier", "mercado", "servicio", "unidad de negocio", "responsable prod", "responsable negocio", "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sept", "oct", "nov", "dec", "linea negocio"]

		results = [headers]
		# users = User.active
		users = User.find(TimeEntry.where(tyear: year).distinct(:user_id).map(&:user_id))

		users.each do |u|
			projects = Project.find(TimeEntry.where(user_id: u.id, tyear: year).distinct(:project_id).map(&:project_id)) #u.projects.active

			projects.each do |p|
				te = TimeEntry.where(user_id: u.id, project_id: p.id, tyear: year)

				if te.present?
					result = []

					result << u.login
					result << p.name
					result << p.identifier
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_LOCALIZACION_ID).first) ? (cf.present? ? cf.value : '') : 0
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_SERVICIO_ID).first) ? (cf.present? ? cf.value : '') : 0
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_UNEGOCIO_ID).first) ? (cf.present? ? cf.value : '') : 0
					cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_RESP_PRODUCCION).first
					if cf.present? and cf.value.present?
						result << User.find(cf.value).login
					else
						result << ''
					end
					cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_RESP_NEGOCIO).first
					if cf.present? and cf.value.present?
						result << User.find(cf.value).login
					else
						result << ''
					end
					(1..12).each do |i|
						result << te.where(tmonth: i).sum(:hours)
					end

					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_SUBUNIDADNEG_ID).first) ? (cf.present? ? cf.value : '') : 0

					results << result
				end
			end
		end

		generate_csv("time_entries_last_year", results)
	end

	def get_projects_with_cost_overrun_last_year
		projects = Project.active.reject{|p| p.ancestors.detect{|a| a.bsc_end_date.present?}}
		headers = []
		results = [[]]

		projects.each do |p|
			maux = BSC::MetricsInterval.new(p.id, Date.parse((Date.today.year-1).to_s+"-01-01"), Date.parse((Date.today.year-1).to_s+"-12-31"), {:descendants => false})

			if maux.hhrr_cost_scheduled_checkpoint > 0 and maux.total_expense_incurred - (maux.hhrr_cost_scheduled_checkpoint + maux.variable_expense_scheduled + maux.fixed_expense_scheduled) > 0
				puts "#{p.identifier}"
				include_descendants = (p.bsc_end_date.present? and p.parent_id != ARCHIVADOS_PROJECT_ID)
				start_year = maux.real_start_date.year
				end_year = maux.real_finish_date.year

				(["total"]+Array(start_year..end_year)).each do |year|
					if year == "total"
						metrics = BSC::Metrics.new(p.id, Date.today, {:descendants => include_descendants})
					else
						metrics = BSC::MetricsInterval.new(p.id, Date.parse(year.to_s+"-01-01"), Date.parse(year.to_s+"-12-31"), {:descendants => include_descendants})
					end

					# if maux.total_income_scheduled != 0 or maux.variable_expense_scheduled != 0 or maux.hhrr_cost_incurred != 0 or maux.fixed_expense_scheduled != 0 or (start_year <= Date.today.year and end_year >= Date.today.year)
						puts "Atributos del proyecto"
						headers = []
						result = []
						headers << "id"
						result << p.id
						headers << "name"
						result << p.name
						headers << "identifier"
						result << p.identifier
						headers << "año"
						result << year
						puts "Checkpoint"
						headers << "ultimo punto de control"
						result << (p.last_checkpoint ? p.last_checkpoint.checkpoint_date : "-")
						headers << "fecha de fin"
						result << maux.scheduled_finish_date
						puts "MC"
						headers << "mc incurrido"
						result << (metrics.total_income_incurred - metrics.total_expense_incurred).round(2)
						headers << "mc"
						result << (metrics.total_income_scheduled - metrics.total_expense_scheduled).round(2)
						headers << "%mc"
						result << metrics.scheduled_margin.round(2)
						headers << "mc objetivo"
						result << metrics.margin_target.round(2)
						headers << "coste objetivo"
						result << metrics.expenses_target.round(2)
						headers << "ingresos objetivo"
						result << metrics.incomes_target.round(2)
						puts "Scheduled"
						headers << "bpo estimado"
						result << metrics.fixed_expense_scheduled.round(2)
						headers << "esfuerzo estimado"
						se = ((year == "total") ? metrics.hhrr_cost_scheduled : metrics.hhrr_cost_scheduled_checkpoint)
						result << se.round(2)
						VARIABLE_EXPENSES.each do |expense|
							headers << expense.downcase+" estimado"
							result << metrics.variable_expense_scheduled_by_tracker[expense].round(2)
						end
						VARIABLE_INCOMES.each do |income|
							headers << income.downcase+" estimado"
							result << metrics.variable_income_scheduled_by_tracker[income].round(2)
						end

						puts "Incurred"
						headers << "bpo incurrido"
						result << metrics.fixed_expense_incurred.round(2)
						headers << "esfuerzo incurrido"
						result << metrics.hhrr_cost_incurred.round(2)
						VARIABLE_EXPENSES.each do |expense|
							headers << expense.downcase+" incurrido"
							result << metrics.variable_expense_incurred_by_tracker[expense].round(2)
						end
						VARIABLE_INCOMES.each do |income|
							headers << income.downcase+" incurrido"
							result << metrics.variable_income_incurred_by_tracker[income].round(2)
						end

						puts "Remaining"
						headers << "bpo restantes"
						result << metrics.fixed_expense_remaining.round(2)
						headers << "esfuerzo restantes"
						result << metrics.hhrr_cost_remaining.round(2)
						VARIABLE_EXPENSES.each do |expense|
							headers << expense.downcase+" restante"
							result << ((metrics.variable_expense_scheduled_by_tracker[expense] || 0.0) - (metrics.variable_expense_incurred_by_tracker[expense] || 0.0)).round(2)
						end
						VARIABLE_INCOMES.each do |income|
							headers << income.downcase+" restante"
							result << ((metrics.variable_income_scheduled_by_tracker[income] || 0.0) - (metrics.variable_income_incurred_by_tracker[income] || 0.0)).round(2)
						end

						headers << "%consecución (puntos de control)"
						result << ((p.last_checkpoint.present? and p.last_checkpoint.achievement_percentage.present?) ? p.last_checkpoint.achievement_percentage.round(2) : "-")
						headers << "%consecución (avance peticiones)"
						result << ((year == 'total') ? (p.issues.map(&:done_ratio).sum/p.issues.count.to_f).round(2) : '-')
	                    headers << "Padre ID"
	                    result << p.parent_id

	                    puts "Campos del proyecto"
						# Campos Estado, Servicio, Localización geográfica y Unidad de negocio
						headers << "estado"
						result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_ESTADO_ID).first) ? (cf.present? ? cf.value : '') : 0
						headers << "localizacion"
						result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_LOCALIZACION_ID).first) ? (cf.present? ? cf.value : '') : 0
						headers << "servicio"
						result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_SERVICIO_ID).first) ? (cf.present? ? cf.value : '') : 0
						headers << "unidad de negocio"
						result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_UNEGOCIO_ID).first) ? (cf.present? ? cf.value : '') : 0
						headers << "responsable producción"
						cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_RESP_PRODUCCION).first
						if cf.present? and cf.value.present?
							result << User.find(cf.value).login
						else
							result << ''
						end
						headers << "responsable negocio"
						cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_RESP_NEGOCIO).first
						if cf.present? and cf.value.present?
							result << User.find(cf.value).login
						else
							result << ''
						end

						# p.versions.map{|v| v.completed_percent.to_f * v.issues_count.to_f / 100.0}.sum / p.issues.count.to_f)
						results << result
					# end
					results[0] = headers
				end
			end
		end

		generate_csv("projects_with_cost_overrun_last_year", results)
	end

	def time_entries_daily
		start_date = Date.today - 60.days
		end_date = Date.today
		headers = ["user", "project_name", "project_identifier", "mercado", "servicio", "unidad de negocio", "responsable prod", "responsable negocio"]

		(start_date..end_date).each do |date|
			headers << date.strftime('%d/%m/%Y')
		end

		results = [headers]
		# users = User.active
		users = User.find(TimeEntry.where(spent_on: start_date..end_date).distinct(:user_id).map(&:user_id))

		users.each do |u|
			projects = Project.find(TimeEntry.where(user_id: u.id, spent_on: start_date..end_date).distinct(:project_id).map(&:project_id)) #u.projects.active

			projects.each do |p|
				te = TimeEntry.where(user_id: u.id, project_id: p.id, spent_on: start_date..end_date)

				if te.present?
					result = []

					result << u.login
					result << p.name
					result << p.identifier
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_LOCALIZACION_ID).first) ? (cf.present? ? cf.value : '') : 0
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_SERVICIO_ID).first) ? (cf.present? ? cf.value : '') : 0
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_UNEGOCIO_ID).first) ? (cf.present? ? cf.value : '') : 0
					cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_RESP_PRODUCCION).first
					if cf.present? and cf.value.present?
						result << User.find(cf.value).login
					else
						result << ''
					end
					cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_RESP_NEGOCIO).first
					if cf.present? and cf.value.present?
						result << User.find(cf.value).login
					else
						result << ''
					end
					(start_date..end_date).each do |date|
						result << te.where(spent_on: date).sum(:hours)
					end

					results << result
				end
			end
		end

		generate_csv("time_entries_last_60_days", results)
	end

	def time_entries_last_months
		start_date = (Date.today - 3.months).at_beginning_of_month
		end_date = Date.today
		number_of_months = (end_date.year*12+end_date.month)-(start_date.year*12+start_date.month)

		headers = ["user", "project_name", "project_identifier", "mercado", "servicio", "unidad de negocio", "responsable prod", "responsable negocio"]

		(0..number_of_months).each do |n|
			headers << (start_date + n.months).strftime('%m/%Y')
		end

		results = [headers]
		# users = User.active
		users = User.find(TimeEntry.where(spent_on: start_date..end_date).distinct(:user_id).map(&:user_id))

		users.each do |u|
			projects = Project.find(TimeEntry.where(user_id: u.id, spent_on: start_date..end_date).distinct(:project_id).map(&:project_id)) #u.projects.active

			projects.each do |p|
				te = TimeEntry.where(user_id: u.id, project_id: p.id, spent_on: start_date..end_date)

				if te.present?
					result = []

					result << u.login
					result << p.name
					result << p.identifier
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_LOCALIZACION_ID).first) ? (cf.present? ? cf.value : '') : 0
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_SERVICIO_ID).first) ? (cf.present? ? cf.value : '') : 0
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_UNEGOCIO_ID).first) ? (cf.present? ? cf.value : '') : 0
					cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_RESP_PRODUCCION).first
					if cf.present? and cf.value.present?
						result << User.find(cf.value).login
					else
						result << ''
					end
					cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_RESP_NEGOCIO).first
					if cf.present? and cf.value.present?
						result << User.find(cf.value).login
					else
						result << ''
					end
					(0..number_of_months).each do |n|
						result << te.where(tmonth: (start_date + n.months).month).sum(:hours)
					end

					results << result
				end
			end
		end

		generate_csv("time_entries_last_4_months", results)
	end

	def user_profile_cost_last_months
		start_date = (Date.today - 3.months).at_beginning_of_month
		end_date = Date.today
		number_of_months = (end_date.year*12+end_date.month)-(start_date.year*12+start_date.month)

		headers = ["user", "project_name", "project_identifier", "mercado", "servicio", "unidad de negocio", "responsable prod", "responsable negocio"]

		(0..number_of_months).each do |n|
			headers << (start_date + n.months).strftime('%m/%Y')
		end

		results = [headers]
		# users = User.active
		users = User.find(TimeEntry.where(spent_on: start_date..end_date).distinct(:user_id).map(&:user_id))

		users.each do |u|
			projects = Project.find(TimeEntry.where(user_id: u.id, spent_on: start_date..end_date).distinct(:project_id).map(&:project_id)) #u.projects.active

			projects.each do |p|
				te = TimeEntry.where(user_id: u.id, project_id: p.id, spent_on: start_date..end_date)

				if te.present?
					result = []

					result << u.login
					result << p.name
					result << p.identifier
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_LOCALIZACION_ID).first) ? (cf.present? ? cf.value : '') : 0
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_SERVICIO_ID).first) ? (cf.present? ? cf.value : '') : 0
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_UNEGOCIO_ID).first) ? (cf.present? ? cf.value : '') : 0
					cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_RESP_PRODUCCION).first
					if cf.present? and cf.value.present?
						result << User.find(cf.value).login
					else
						result << ''
					end
					cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_RESP_NEGOCIO).first
					if cf.present? and cf.value.present?
						result << User.find(cf.value).login
					else
						result << ''
					end
					(0..number_of_months).each do |n|
						if te.where(tmonth: (start_date + n.months).month).present?
							aux_date = start_date + n.months
							profile = HrProfile.joins(:user_profiles).where('hr_user_profiles.user_id = ? AND (hr_user_profiles.end_date IS NOT NULL AND ? BETWEEN hr_user_profiles.start_date AND hr_user_profiles.end_date OR hr_user_profiles.end_date IS NULL AND ? >= hr_user_profiles.start_date)', u.id, aux_date, aux_date)
							result << (profile.one? ? profile.take.name : '')
						else
							result << ''
						end
					end

					results << result
				end
			end
		end

		generate_csv("user_profile_cost_last_4_months", results)
	end

	def generate_csv(filename, data)
		CSV.open("public/"+filename+".csv","w",:col_sep => ';',:encoding=>'UTF-8') do |file|
			data.each do |row|
				file << row
			end
		end
	end
end
