require 'csv'

namespace :bsc2 do
	task :time_entries_record => :environment do
		time_entries_daily
		projects_list
	end

	def time_entries_daily
		year = Date.today.year
		start_date = Date.today.beginning_of_year
		end_date = Date.today
		headers = ["user", "project_name", "project_identifier", "mercado", "servicio", "unidad de negocio", "responsable prod", "responsable negocio"]

		(start_date..end_date).each do |date|
			headers << date.strftime('%d/%m/%Y')
		end

		results = [headers]
		# users = User.active
		users = User.find(TimeEntry.where(spent_on: start_date..end_date).distinct(:user_id).map(&:user_id))

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
					(start_date..end_date).each do |date|
						result << te.where(spent_on: date).sum(:hours)
					end

					results << result
				end
			end
		end

		generate_csv("daily_time_entries", results)
	end

	def projects_list
		start_date = Date.today.beginning_of_year

		projects = Project.where("status = 1 OR status = 9 AND updated_on >= ?", start_date)

		headers = ["id", "project_name", "project_identifier", "mercado", "servicio", "unidad de negocio", "responsable prod", "responsable negocio"]

		results = [headers]

		projects.each do |p|
			result = []

			result << p.id
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

			results << result
		end

		generate_csv("projects_list", results)
	end
end