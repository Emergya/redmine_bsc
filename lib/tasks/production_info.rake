require 'csv'
CF_SERVICIO_ID = 102
CF_REGION_ID = 166
CF_UNEGOCIO_ID = 275 
CF_RESP_PRODUCCION = 276
CF_RESP_NEGOCIO = 277

namespace :bsc2 do
	task :production_info => :environment do
		user_profiles
		time_entries
		checkpoints
		profiles_cost
	end

	def user_profiles
		headers = ["login", "name", "rol", "start_date", "end_date"]
		results = [headers]

		users = User.active
		users.each do |user|
			profiles = user.profiles

			profiles.each do |profile|
				result = []

				result << user.login
				result << user.name
				result << profile.profile.name
				result << profile.start_date
				result << profile.end_date
			
				results << result
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
					result << p.custom_values.find_by(custom_field_id: CF_REGION_ID).value
					result << p.custom_values.find_by(custom_field_id: CF_SERVICIO_ID).value
					result << p.custom_values.find_by(custom_field_id: CF_UNEGOCIO_ID).value
					cf = p.custom_values.find_by(custom_field_id: CF_RESP_PRODUCCION)
					if cf.present? and cf.value.present?
						result << User.find(cf.value).login
					else
						result << ''
					end
					cf = p.custom_values.find_by(custom_field_id: CF_RESP_NEGOCIO)
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

		generate_csv("time_entries", results)
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

	def generate_csv(filename, data)
		CSV.open("public/"+filename+".csv","w",:col_sep => ';',:encoding=>'UTF-8') do |file|
			data.each do |row|
				file << row
			end
		end
	end
end