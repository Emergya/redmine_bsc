require 'csv'

desc 'Generate CSV to feed Emergya Profitability Sheet'
# YEARS = 5
# VARIABLE_EXPENSES = ['Providers', 'Other expenses', 'Subsistence allowance', 'Other expenses HHRR']
VARIABLE_EXPENSES = ['Providers', 'Expenses']
# VARIABLE_INCOMES = ['Bills', 'Other incomes']
VARIABLE_INCOMES = ['Bills']

ARCHIVADOS_PROJECT_ID = 82
CF_ESTADO_ID = 120
# CF_EXPEDIENTE_ID = 26
CF_UNEGOCIO_ID = 26
CF_SERVICIO_ID = 102
# CF_REGION_ID = 166 # Renombrado a Mercado
CF_LOCALIZACION_ID = 166 # Renombrado a Mercado
CF_TIPO_ID = 18 # Renombrado a Ciclo de vida
CF_JP_ID = 0
CF_GCUENTAS_ID = 0

namespace :bsc2 do
	task :generate_csv => :environment do
		projects = Project.active.reject{|p| p.ancestors.detect{|a| a.bsc_end_date.present?}}
		headers = []
		results = [[]]

		projects.each do |p|
			maux = BSC::MetricsInterval.new(p.id, Date.parse(Date.today.year.to_s+"-01-01"), Date.parse(Date.today.year.to_s+"-12-31"), {:descendants => false})
			include_descendants = (p.bsc_end_date.present? and (p.parent_id != ARCHIVADOS_PROJECT_ID or maux.hhrr_hours_incurred_by_profile.reject{|k,v| k==nil}.present?) )
			# (["total"]+Array(Date.today.year..Date.today.year+YEARS)).each do |year|

			start_year = maux.scheduled_start_date ? maux.scheduled_start_date.year : maux.real_start_date.year
			end_year = maux.scheduled_finish_date ? maux.scheduled_finish_date.year : maux.real_finish_date.year

			(["total"]+Array(start_year..end_year)).each do |year|
				if year == "total"
					metrics = BSC::Metrics.new(p.id, Date.today, {:descendants => include_descendants})
				else
					metrics = BSC::MetricsInterval.new(p.id, Date.parse(year.to_s+"-01-01"), Date.parse(year.to_s+"-12-31"), {:descendants => include_descendants})
				end

				if maux.total_income_scheduled != 0 or maux.variable_expense_scheduled > 0 or maux.hhrr_cost_incurred > 0 or maux.fixed_expense_scheduled > 0 or (start_year <= Date.today.year and end_year >= Date.today.year)
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
					headers << "jefe de proyecto"
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_JP_ID).first) ? (cf.present? ? cf.value : '') : 0
					headers << "gestor de cuentas"
					result << (cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_GCUENTAS_ID).first) ? (cf.present? ? cf.value : '') : 0
					headers << "ultimo punto de control"
					result << (p.last_checkpoint ? p.last_checkpoint.checkpoint_date : "-")
					headers << "fecha de fin"
					result << metrics.scheduled_finish_date
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
						headers << expense+" estimado"
						result << metrics.variable_expense_scheduled_by_tracker[expense]
					end
					VARIABLE_INCOMES.each do |income|
						headers << income+" estimado"
						result << metrics.variable_income_scheduled_by_tracker[income]
					end
					puts "Incurred"
					headers << "bpo incurrido"
					result << metrics.fixed_expense_incurred
					headers << "esfuerzo incurrido"
					result << metrics.hhrr_cost_incurred
					VARIABLE_EXPENSES.each do |expense|
						headers << expense+" incurrido"
						result << metrics.variable_expense_incurred_by_tracker[expense]
					end
					VARIABLE_INCOMES.each do |income|
						headers << income+" incurrido"
						result << metrics.variable_income_incurred_by_tracker[income]
					end
					puts "Remaining"
					headers << "bpo restantes"
					result << metrics.fixed_expense_remaining
					headers << "esfuerzo restantes"
					result << metrics.hhrr_cost_remaining
					VARIABLE_EXPENSES.each do |expense|
						headers << expense+" restante"
						result << (metrics.variable_expense_scheduled_by_tracker[expense] || 0.0) - (metrics.variable_expense_incurred_by_tracker[expense] || 0.0)
					end
					VARIABLE_INCOMES.each do |income|
						headers << income+" restante"
						result << (metrics.variable_income_scheduled_by_tracker[income] || 0.0) - (metrics.variable_income_incurred_by_tracker[income] || 0.0)
					end

					results << result
				end
				results[0] = headers
			end
		end

		CSV.open("public/nre_results.csv","w",:col_sep => ';',:encoding=>'UTF-8') do |file|
			results.each do |result|
				file << result
			end
		end
	end

	def effort_scheduled(checkpoint, profile)
	end

end