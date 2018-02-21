require 'csv'
CF_SERVICIO_ID = 102
CF_LOCALIZACION_ID = 166
CF_UNEGOCIO_ID = 275 
CF_RESP_PRODUCCION = 276
CF_RESP_NEGOCIO = 277

VARIABLE_EXPENSES = ['Providers', 'Other expenses', 'Subsistence allowance', 'Other expenses HHRR']
VARIABLE_INCOMES = ['Clients', 'Other incomes']

ARCHIVADOS_PROJECT_ID = 82
CF_ESTADO_ID = 120
CF_EXPEDIENTE_ID = 26
CF_INICO_GARANTIA_ID = 264
CF_FIN_GARANTIA_ID = 265

namespace :bsc2 do
	task :production_info => :environment do
		user_profiles
		time_entries
		checkpoints
		profiles_cost
		time_entries_years
		generate_projects_data
	end

	def user_profiles
		headers = ["login", "name", "rol", "start_date", "end_date"]
		results = [headers]

		users = User.active
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
		headers = ["user", "project_name", "project_identifier", "mercado", "servicio", "unidad de negocio", "responsable prod", "responsable negocio", "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sept", "oct", "nov", "dec"]

		results = [headers]
		users = User.active

		users.each do |u|
			projects = u.projects.active

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

		results = [headers]
		projects = Project.active

		projects.each do |project|
			checkpoints = project.bsc_checkpoints

			checkpoints.each do |checkpoint|
				result = []

				result << checkpoint.id
				result << project.identifier
				result << checkpoint.checkpoint_date

				efforts = Hash.new(0.0).merge(checkpoint.bsc_checkpoint_efforts.map{|eff| [eff.hr_profile_id, eff.scheduled_effort]}.to_h)
				HrProfile.all.each do |profile|
					result << efforts[profile.id]
				end

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
		users = User.active

		users.each do |u|
			projects = u.projects.active

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

			start_year = maux.scheduled_start_date ? maux.scheduled_start_date.year : maux.real_start_date.year
			end_year = maux.scheduled_finish_date ? maux.scheduled_finish_date.year : maux.real_finish_date.year

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

						# p.versions.map{|v| v.completed_percent.to_f * v.issues_count.to_f / 100.0}.sum / p.issues.count.to_f)
					results << result
				# end
				results[0] = headers
			end
		end

		generate_csv("projects_data", results)
	end

	def generate_csv(filename, data)
		CSV.open("public/"+filename+".csv","w",:col_sep => ';',:encoding=>'UTF-8') do |file|
			data.each do |row|
				file << row
			end
		end
	end
end