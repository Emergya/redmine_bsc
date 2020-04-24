require 'csv'

TRACKERS_ID = [23,43,44,65,66,67,68]
CF_SERVICIO_ID = 102
CF_LOCALIZACON_ID =  166
CF_UNEGOCIO_ID = 275

CF_EMPRESA = 156
CF_IMPORTE_LOCAL = 261
CF_MONEDA = 263
CF_IMPORTE = 152
CF_FECHA_FACTURACION = 153
CF_RESP_PRODUCCION = 276
CF_RESP_NEGOCIO = 277
CF_LINEA_NEGOCIO = 288

CF_IVA = 155
CF_IMPORTE_IVA = 159
CF_IMPORTE_LOCAL_IVA = 272

CF_TIPO_FACTURA = 207
CF_TIPO_INGRESO = 273
CF_TIPO_GASTO = 274
CF_TIPO_GASTO_RRHH = 282
CF_CLIENTE = 28
CF_TERCEROS = 271
CF_NUM_FACTURA = 204
CF_FECHA_COBRO = 154

CF_JP_ID = 276
CF_GCUENTAS_ID = 277


BILL_TRACKER = 23


namespace :bsc2 do
	task :get_data => :environment do
		projects = Project.active

		TRACKERS_ID.each do |tracker_id|
			headers = []
			results = [[]]
			issues = Issue.joins(:project).where("tracker_id = ? AND projects.status = ? AND YEAR(issues.created_on) >= ?", tracker_id, 1, Date.today.year-3)

			issues.each do |issue|
				headers = []
				result = []
				headers << "id"
				result << issue.id
				headers << "title"
				result << issue.subject
				headers << "project"
				result << issue.project.identifier
				headers << "status"
				result << issue.status.name
				headers << "servicio"
				result << (cf = issue.project.custom_values.where(custom_field_id: CF_SERVICIO_ID).first) ? (cf.present? ? cf.value : '') : ''
				headers << "localizacion"
				result << (cf = issue.project.custom_values.where(custom_field_id: CF_LOCALIZACON_ID).first) ? (cf.present? ? cf.value : '') : ''
				headers << "unidad negocio"
				result << (cf = issue.project.custom_values.where(custom_field_id: CF_UNEGOCIO_ID).first) ? (cf.present? ? cf.value : '') : ''
				headers << "responsable producción"
				cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", issue.project_id, CF_JP_ID).first
				if cf.present? and cf.value.present?
					result << User.find(cf.value).login
				else
					result << ''
				end
				headers << "responsable negocio"
				cf = CustomValue.where("customized_id = ? AND customized_type = 'Project' AND custom_field_id = ?", issue.project_id, CF_GCUENTAS_ID).first
				if cf.present? and cf.value.present?
					result << User.find(cf.value).login
				else
					result << ''
				end				
				headers << "empresa"
				result << (cf = issue.custom_values.where(custom_field_id: CF_EMPRESA).first) ? (cf.present? ? cf.value : '') : ''
				headers << "cliente/terceros"
				result << (cf = issue.custom_values.where(custom_field_id: CF_CLIENTE).first || issue.custom_values.where(custom_field_id: CF_TERCEROS).first) ? (cf.present? ? cf.value : '') : ''
				headers << "tipo factura/ingreso/gasto"
				result << (cf = issue.custom_values.where(custom_field_id: CF_TIPO_FACTURA).first || issue.custom_values.where(custom_field_id: CF_TIPO_INGRESO).first || issue.custom_values.where(custom_field_id: CF_TIPO_GASTO).first || issue.custom_values.where(custom_field_id: CF_TIPO_GASTO_RRHH).first) ? (cf.present? ? cf.value : '') : ''
				headers << "num factura"
				result << (cf = issue.custom_values.where(custom_field_id: CF_NUM_FACTURA).first) ? (cf.present? ? cf.value : '') : ''
				headers << "fecha creación"
				result << issue.created_on.to_date
				headers << "fecha facturacion"
				result << (cf = issue.custom_values.where(custom_field_id: CF_FECHA_FACTURACION).first) ? (cf.present? ? cf.value : '') : ''
				headers << "fecha cobro"
				result << (cf = issue.custom_values.where(custom_field_id: CF_FECHA_COBRO).first) ? (cf.present? ? cf.value : '') : ''
				headers << "moneda"
				result << (cf = issue.custom_values.where(custom_field_id: CF_MONEDA).first) ? (cf.present? ? (cf.value ? Currency.find(cf.value).name : '') : '') : ''
				headers << "iva"
				result << (cf = issue.custom_values.where(custom_field_id: CF_IVA).first) ? (cf.present? ? cf.value : '') : ''
				headers << "importe(moneda local)"
				result << (cf = issue.custom_values.where(custom_field_id: CF_IMPORTE_LOCAL).first) ? (cf.present? ? cf.value : '') : ''
				headers << "importe"
				result << (cf = issue.custom_values.where(custom_field_id: CF_IMPORTE).first) ? (cf.present? ? cf.value : '') : ''
				headers << "importe local(con iva)"
				result << (cf = issue.custom_values.where(custom_field_id: CF_IMPORTE_LOCAL_IVA).first) ? (cf.present? ? cf.value : '') : ''
				headers << "importe(con iva)"
				result << (cf = issue.custom_values.where(custom_field_id: CF_IMPORTE_IVA).first) ? (cf.present? ? cf.value : '') : ''
				headers << "linea negocio"
				result << (cf = issue.project.custom_values.where(custom_field_id: CF_LINEA_NEGOCIO).first) ? (cf.present? ? cf.value : '') : ''
				if [65,66,67,68].include?(tracker_id)
					headers << "categoria"
					result << (issue.category ? issue.category.name : '')
				end

				results << result
			end
			results[0] = headers

			CSV.open("public/"+Tracker.find(tracker_id).name.parameterize.underscore+".csv","w",:col_sep => ';',:encoding=>'UTF-8') do |file|
				results.each do |result|
					file << result
				end
			end
		end

		
	end

	task :get_bill_changes => :environment do
		year = Date.today.year
		zone = ActiveSupport::TimeZone.new("Madrid")
		headers = ["id", "subject", "unidad negocio", "project", "responsable producción", "moneda", "importe (moneda local)", "fecha facturación", "estado", "fecha actualización", "hora actualización", "autor"]
		results = [[]]

		projects = Project.active
		projects.each do |project|
			result_project = []

			# Unidad negocio
			result_project << (cf = project.custom_values.where(custom_field_id: CF_UNEGOCIO_ID).first) ? (cf.present? ? cf.value : '') : ''
			# Project
			result_project << project.identifier
			# Responsable producción
			cf = project.custom_values.find_by(custom_field_id: CF_JP_ID)
			if cf.present? and cf.value.present?
				result_project << User.find(cf.value).login
			else
				result_project << ''
			end

			# bills = project.issues.where(tracker_id: BILL_TRACKER)
			bills = project.issues.joins(:custom_values).where("tracker_id = ? AND custom_values.custom_field_id = ? AND custom_values.value >= ?", BILL_TRACKER, CF_FECHA_FACTURACION, "#{year}-01-01")
			bills.each do |bill|
				result_bill = []

				moneda_inicial = JournalDetail.joins(:journal).order('journals.created_on ASC').find_by("journals.journalized_type = ? AND journals.journalized_id = ? AND property = ? AND prop_key = ?", 'Issue', bill.id, 'cf', CF_MONEDA)
				moneda_inicial = moneda_inicial.present? ? moneda_inicial.old_value : ((cf = bill.custom_values.find_by(custom_field_id: CF_MONEDA)).present? ? cf.value : '')
				ultima_moneda = moneda_inicial
				importe_inicial = JournalDetail.joins(:journal).order('journals.created_on ASC').find_by("journals.journalized_type = ? AND journals.journalized_id = ? AND property = ? AND prop_key = ?", 'Issue', bill.id, 'cf', CF_IMPORTE_LOCAL)
				importe_inicial = importe_inicial.present? ? importe_inicial.old_value : ((cf = bill.custom_values.find_by(custom_field_id: CF_IMPORTE_LOCAL)).present? ? cf.value : '')
				ultimo_importe = importe_inicial
				ffacturacion_inicial = JournalDetail.joins(:journal).order('journals.created_on ASC').find_by("journals.journalized_type = ? AND journals.journalized_id = ? AND property = ? AND prop_key = ?", 'Issue', bill.id, 'cf', CF_FECHA_FACTURACION)
				ffacturacion_inicial = ffacturacion_inicial.present? ? ffacturacion_inicial.old_value : ((cf = bill.custom_values.find_by(custom_field_id: CF_FECHA_FACTURACION)).present? ? cf.value : '')
				ultima_ffacturacion = ffacturacion_inicial
				estado_inicial = JournalDetail.joins(:journal).order('journals.created_on ASC').find_by("journals.journalized_type = ? AND journals.journalized_id = ? AND property = ? AND prop_key = ?", 'Issue', bill.id, 'attr', 'status_id')
				estado_inicial = estado_inicial.present? ? ((status = IssueStatus.find(estado_inicial.old_value)).present? ? status.name : '') : bill.status.name
				ultimo_estado = estado_inicial

				# Id
				result_bill << bill.id
				# Subject
				result_bill << bill.subject

				result_bill += result_project

				result = result_bill.clone

				# Moneda
				result << (moneda_inicial.present? ? ((cfe = CustomFieldEnumeration.find(moneda_inicial)).present? ? cfe.name : '') : '')
				# Importe
				result << importe_inicial
				# Fecha facturacion
				result << (ffacturacion_inicial.present? ? ffacturacion_inicial.to_date : ((cf = bill.custom_values.find_by(custom_field_id: CF_FECHA_FACTURACION)).present? ? cf.value.to_date : ''))
				# Estado
				result << estado_inicial #(estado_inicial.present? ? ((status = IssueStatus.find(estado_inicial)).present? ? status.name : '') : '')
				# Fecha actualizacion
				result << bill.created_on.in_time_zone(zone).strftime("%Y-%m-%d")
				# Hora actualizacion
				result << bill.created_on.in_time_zone(zone).strftime("%H:%M:%S")
				# Autor
				result << ((user = bill.author).present? ? user.login : '')

				results << result

				journals = bill.journals.joins(:details).where("(property = ? AND prop_key IN (?)) OR (property = ? AND prop_key = ?)", "cf", [CF_IMPORTE_LOCAL, CF_FECHA_FACTURACION], 'attr', 'status_id').group('journals.id').order('journals.created_on ASC')
				journals.each do |journal|
					result = result_bill.clone

					# Moneda
					moneda = journal.details.find_by("property = ? AND prop_key = ?", "cf", CF_MONEDA)
					ultima_moneda = moneda.value if moneda.present?
					result << (ultima_moneda.present? ? ((cfe = CustomFieldEnumeration.find(ultima_moneda)).present? ? cfe.name : '') : '')


					# Importe
					importe = journal.details.find_by("property = ? AND prop_key = ?", "cf", CF_IMPORTE_LOCAL)
					ultimo_importe = importe.value if importe.present?
					result << ultimo_importe.to_f

					# Fecha facturacion
					ffacturacion = journal.details.find_by("property = ? AND prop_key = ?", "cf", CF_FECHA_FACTURACION)
					ultima_ffacturacion = ffacturacion.value if ffacturacion.present?
					result << ultima_ffacturacion.to_date if ultima_ffacturacion.present?

					# Estado
					estado = journal.details.find_by("property = ? AND prop_key = ?", "attr", 'status_id')
					ultimo_estado = ((status = IssueStatus.find(estado.value)).present? ? status.name : '') if estado.present?
					result << ultimo_estado #(ultimo_estado.present? ? ((status = IssueStatus.find(ultimo_estado)).present? ? status.name : '') : '')

					# Fecha actualizacion
					result << journal.created_on.in_time_zone(zone).strftime("%Y-%m-%d")

					# Fecha actualizacion
					result << journal.created_on.in_time_zone(zone).strftime("%H:%M:%S")

					# Autor
					result << ((user = journal.user).present? ? user.login : '')

					results << result
				end
			end
		end
		results[0] = headers

		CSV.open("public/bill_changes.csv","w",:col_sep => ';',:encoding=>'UTF-8') do |file|
			results.each do |result|
				file << result
			end
		end
	end

	def effort_scheduled(checkpoint, profile)
	end

end
