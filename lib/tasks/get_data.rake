require 'csv'

TRACKERS_ID = [23,43,62,65,66,67,68]
CF_SERVICIO_ID = 102
CF_LOCALIZACON_ID =  166
CF_UNEGOCIO_ID = 272

CF_EMPRESA = 156
CF_IMPORTE_LOCAL = 261
CF_MONEDA = 263
CF_IMPORTE = 152
CF_FECHA_FACTURACION = 153
CF_RESP_PRODUCCION = 273
CF_RESP_NEGOCIO = 274

CF_IVA = 155
CF_IMPORTE_IVA = 159
CF_IMPORTE_LOCAL_IVA = 275

CF_TIPO_FACTURA = 207
CF_TIPO_INGRESO = 276
CF_TIPO_GASTO = 277
CF_CLIENTE = 28
CF_TERCEROS = 271
CF_NUM_FACTURA = 204
CF_FECHA_COBRO = 154



namespace :bsc2 do
	task :get_data => :environment do
		projects = Project.active

		TRACKERS_ID.each do |tracker_id|
			headers = []
			results = [[]]
			issues = Issue.joins(:project).where("tracker_id = ? AND projects.status = ? AND YEAR(issues.created_on) >= ?", tracker_id, 1, Date.today.year)

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
				result << (cf = issue.project.custom_values.where(custom_field_id: CF_RESP_PRODUCCION).first) ? (cf.present? ? cf.value : '') : ''
				headers << "responsable negocio"
				result << (cf = issue.project.custom_values.where(custom_field_id: CF_RESP_NEGOCIO).first) ? (cf.present? ? cf.value : '') : ''
				headers << "empresa"
				result << (cf = issue.custom_values.where(custom_field_id: CF_EMPRESA).first) ? (cf.present? ? cf.value : '') : ''
				headers << "cliente/terceros"
				result << (cf = issue.custom_values.where(custom_field_id: CF_CLIENTE).first || issue.custom_values.where(custom_field_id: CF_TERCEROS).first) ? (cf.present? ? cf.value : '') : ''
				headers << "tipo factura/ingreso/gasto"
				result << (cf = issue.custom_values.where(custom_field_id: CF_TIPO_FACTURA).first || issue.custom_values.where(custom_field_id: CF_TIPO_INGRESO).first || issue.custom_values.where(custom_field_id: CF_TIPO_GASTO).first) ? (cf.present? ? cf.value : '') : ''
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

				results << result
			end
			results[0] = headers

			CSV.open("public/"+Tracker.find(tracker_id).name.downcase+".csv","w",:col_sep => ';',:encoding=>'UTF-8') do |file|
				results.each do |result|
					file << result
				end
			end
		end

		
	end

	def effort_scheduled(checkpoint, profile)
	end

end