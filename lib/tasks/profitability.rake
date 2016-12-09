require 'csv'

desc 'Generate CSV to feed Emergya Profitability Sheet'
ARCHIVADOS_PROJECT_ID = 82
CF_ESTADO_ID = 120
CF_EXPEDIENTE_ID = 26
CF_SERVICIO_ID = 102
CF_REGION_ID = 166 # Renombrado a Mercado
CF_TIPO_ID = 18 # Renombrado a Ciclo de vida
PROFILE_C = 7
PROFILE_JP = 1
PROFILE_AS = 2
PROFILE_A = 3
PROFILE_TS = 4
PROFILE_T = 5
PROFILE_B = 6
ROLE_JP = 37
ROLE_GC = 37

namespace :bsc do
	task :generate_csv => :environment do

		year = Date.today.year
		headers = ["id", "parent_id", "name", "identifier", "estado", "expediente", "unidad de negocio", "servicio", "vendido C", "vendido JP", "vendido AS", "vendido A", "vendido TS", "vendido T", "vendido B", "registrado C", "registrado JP", "registrado AS", "registrado A", "registrado TS", "registrado T", "registrado B", "registrado year C", "registrado year JP", "registrado year AS", "registrado year A", "registrado year TS", "registrado year T", "registrado year B", "previsto C", "previsto JP", "previsto AS", "previsto A", "previsto TS", "previsto T", "previsto B", "previsto fin", "gastos restantes del aÃo", "previsto gastos", "gastos incurridos", "gastos incurridos del aÃo", "ingresos", "ingresos year", "facturado year", "pendiente year", "esfuerzo previsto", "esfuerzo restante", "esfuerzo registrado", "esfuerzo registrado year", "proveedores", "proveedores year", "proveedores year registrado", "proveedores year restante", "bpo total", "bpo year", "JP", "GC", "Region", "Fecha fin inicial", "ingresos year", "proveedores year", "bpo next year", "bpo reg", "bpo year reg", "type", "Fecha de Inicio", "Fecha último checkpoint", "Iniciativa"]
		# Añadimos campos para tracker gastos
		headers += ["gastos", "gastos estimados year", "gastos incurridos year", "gastos restantes year", "gastos next year"]
		results = [headers]
		projects = Project.active.reject{|p| p.ancestors.detect{|a| a.bsc_end_date.present?}}

		projects.each do |p|
			maux = BSC::MetricsInterval.new(p.id, Date.parse(year.to_s+"-01-01"), Date.parse(year.to_s+"-12-31"), {:descendants => false})
			include_descendants = (p.bsc_end_date.present? and (p.parent_id != ARCHIVADOS_PROJECT_ID or maux.hhrr_hours_incurred_by_profile.reject{|k,v| k==nil}.present?) )

			m = BSC::Metrics.new(p.id, Date.today, {:descendants => include_descendants})
			my = BSC::MetricsInterval.new(p.id, Date.parse(year.to_s+"-01-01"), Date.parse(year.to_s+"-12-31"), {:descendants => include_descendants})

			# if my.total_income_scheduled != 0 or my.variable_expense_scheduled > 0 or my.hhrr_cost_incurred > 0 or (p.parent_id != ARCHIVADOS_PROJECT_ID and m.hhrr_hours_remaining_by_profile.reject{|k,v| k==nil}.values.sum > 0) or my.fixed_expense_scheduled > 0
			if my.total_income_scheduled != 0 or my.variable_expense_scheduled > 0 or my.hhrr_cost_incurred > 0 or my.fixed_expense_scheduled > 0


				puts "@@@@@@@@@@@@@@ #{p.identifier} @@@@@@@@@@@@@@" 
				puts "Metricas globales"
				metrics = BSC::Metrics.new(p.id, Date.today, {:descendants => include_descendants})

				puts "Metricas de este año"
				metrics_this_year = BSC::MetricsInterval.new(p.id, Date.parse(year.to_s+"-01-01"), Date.parse(year.to_s+"-12-31"), {:descendants => include_descendants})

				puts "Metricas del próximo año"
				metrics_next_year = BSC::MetricsInterval.new(p.id, Date.parse((year+1).to_s+"-01-01"), Date.parse((year+1).to_s+"-12-31"), {:descendants => include_descendants})

				puts "Atributos del proyecto"
				result = []
				result << p.id
				result << p.parent_id
				result << p.name
				result << p.identifier
				puts "Campos personalizados del proyecto"
				# Campos Estado, Expediente, Unidad de negocio, Servicio
				result << CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_ESTADO_ID).first.value || 0
				result << CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_EXPEDIENTE_ID).first.value || 0
				result << 0
				result << CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_SERVICIO_ID).first.value || 0
				puts "Vendido por perfil"
				# Vendido C, JP, AS, A, TS, T, B
				result << 0
				result << 0
				result << 0
				result << 0
				result << 0
				result << 0
				result << 0
				puts "Registrado por perfil"
				# Registrado C, JP, AS, A, TS, T, B
				hours_incurred = metrics.hhrr_hours_incurred_by_profile
				result << hours_incurred[PROFILE_C]
				result << hours_incurred[PROFILE_JP]
				result << hours_incurred[PROFILE_AS]
				result << hours_incurred[PROFILE_A]
				result << hours_incurred[PROFILE_TS]
				result << hours_incurred[PROFILE_T]
				result << hours_incurred[PROFILE_B]
				puts "Registrado en el año por perfil"
				# Registrado year C, JP, AS, A, TS, T, B
				hours_incurred_year = metrics_this_year.hhrr_hours_incurred_by_profile
				result << hours_incurred_year[PROFILE_C]
				result << hours_incurred_year[PROFILE_JP]
				result << hours_incurred_year[PROFILE_AS]
				result << hours_incurred_year[PROFILE_A]
				result << hours_incurred_year[PROFILE_TS]
				result << hours_incurred_year[PROFILE_T]
				result << hours_incurred_year[PROFILE_B]
				puts "Previsto por perfil"
				# Previsto C, JP, AS, A, TS, T, B
				if p.parent_id != ARCHIVADOS_PROJECT_ID or hours_incurred_year.present? 
					scheduled_effort = metrics.hhrr_hours_scheduled_by_profile
				else
					scheduled_effort = Hash.new(0)
				end
				result << scheduled_effort[PROFILE_C]
				result << scheduled_effort[PROFILE_JP]
				result << scheduled_effort[PROFILE_AS]
				result << scheduled_effort[PROFILE_A]
				result << scheduled_effort[PROFILE_TS]
				result << scheduled_effort[PROFILE_T]
				result << scheduled_effort[PROFILE_B]
				puts "Fecha de fin de proyecto"
				# Previsto fin
				if p.parent_id != ARCHIVADOS_PROJECT_ID or hours_incurred_year.reject{|k,v| k==nil}.present? 
					result << metrics.scheduled_finish_date #(last_checkpoint.present? ? last_checkpoint.scheduled_finish_date : 0) || 0
				else
					result << 0
				end
				puts "Gastos restantes en el año"
				# Gastos restantes
				result << metrics_this_year.variable_expense_scheduled_by_tracker['Proveedores'] - metrics_this_year.variable_expense_incurred_by_tracker['Proveedores']
				puts "Gastos previstos"
				# Gastos previstos
				result << metrics.variable_expense_scheduled_by_tracker['Proveedores']
				puts "Gastos incurridos"
				# Gastos incurridos
				result << metrics.variable_expense_incurred_by_tracker['Proveedores']
				puts "Gastos incurridos en el año"
				# Gastos incurridos año
				result << metrics_this_year.variable_expense_incurred_by_tracker['Proveedores']
				puts "Ingresos previstos"
				# Ingresos previstos
				result << metrics.total_income_scheduled
				puts "Ingresos previstos en el año"
				# Ingresos previstos año
				result << metrics_this_year.variable_income_scheduled
				puts "Ingresos incurridos en el año"
				# Ingresos incurridos año
				result << metrics_this_year.variable_income_incurred
				puts "Ingresos pendientes en el año"
				# Ingresos pendientes año
				result << metrics_this_year.variable_income_remaining
				puts "Coste del esfuerzo previsto"
				# Coste esfuerzo previsto
				result << metrics.hhrr_cost_scheduled
				puts "Coste del esfuerzo restante"
				# Coste esfuerzo restante
				result << metrics.hhrr_cost_remaining
				puts "Coste del esfuerzo incurrido"
				# Coste esfuerzo incurrido
				result << metrics.hhrr_cost_incurred
				puts "Coste del esfuerzo incurrido en el año"
				# Coste esfuerzo incurrido año
				result << metrics_this_year.hhrr_cost_incurred
				puts "Coste de proveedores estimado"
				# Proveedores estimados
				result << metrics.variable_expense_scheduled_by_tracker['Proveedores']
				puts "Coste de proveedores estimado en el año"
				# Proveedores estimados año
				result << metrics_this_year.variable_expense_scheduled_by_tracker['Proveedores']
				puts "Coste de proveedores incurrido en el año"
				# Proveedores incurridos año
				result << metrics_this_year.variable_expense_incurred_by_tracker['Proveedores']
				puts "Coste de proveedores restante en el año"
				# Proveedores restantes año
				# result << metrics_this_year.variable_expense_remaining_by_tracker('Proveedores')
				result << metrics_this_year.variable_expense_scheduled_by_tracker['Proveedores'] - metrics_this_year.variable_expense_incurred_by_tracker['Proveedores']
				puts "Coste de BPO"
				# BPO total
				result << metrics.fixed_expense_scheduled
				puts "Coste de BPO en el año"
				# BPO año
				result << metrics_this_year.fixed_expense_scheduled
				# Jefes de proyecto
				result << User.joins(:members => :roles).where("members.project_id = ? AND roles.id= ?", p.id, ROLE_JP).map(&:login).join(" ")
				# Gestores de cuentas 
				result << User.joins(:members => :roles).where("members.project_id = ? AND roles.id= ?", p.id, ROLE_GC).map(&:login).join(" ")
				# Region
				result << CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_REGION_ID).first.value || 0
				# Fecha fin inicial
				info = p.bsc_info.present? ? (p.bsc_info.scheduled_finish_date || 0) : 0
				result << info
				# Ingresos estimados para el próximo año
				result << metrics_next_year.variable_income_scheduled
				# Proveedores estimados para el próximo año
				result << metrics_next_year.variable_expense_scheduled_by_tracker['Proveedores']
				# BPO estimado para el próximo año
				result << metrics_next_year.fixed_expense_scheduled
				# BPO incurrido
				result << metrics.fixed_expense_incurred
				# BPO incurrido en este año
				result << metrics_this_year.fixed_expense_incurred
				# Tipo
				result << CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", p.id, CF_TIPO_ID).first.value || 0
				# Fecha de inicio
				result << metrics.scheduled_start_date || 0
				# Fecha de último checkpoint
				last_checkpoint_date = p.last_checkpoint.present? ? p.last_checkpoint[:checkpoint_date] : 0
				result << last_checkpoint_date
				# Iniciativa
				result << 0

				puts "Campos de tracker gastos"
				# Gastos estimados totales
				result << metrics.variable_expense_scheduled_by_tracker['Gastos']
				# Gastos estimados para este año
				result << metrics_this_year.variable_expense_scheduled_by_tracker['Gastos']
				# Gastos incurridos para este año
				result << metrics_this_year.variable_expense_incurred_by_tracker['Gastos']
				# Gastos restantes para este año
				result << metrics_this_year.variable_expense_scheduled_by_tracker['Gastos'] - metrics_this_year.variable_expense_incurred_by_tracker['Gastos']
				# Gastos estimados para el año próximo
				result << metrics_next_year.variable_expense_scheduled_by_tracker['Gastos']

				results << result
			end
		end

		CSV.open("results.csv","w",:col_sep => ';') do |file|
			results.each do |result|
				file << result
			end
		end
	end

	def effort_scheduled(checkpoint, profile)
	end

end