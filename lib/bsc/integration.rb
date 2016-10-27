module BSC
	class Integration
		class << self
			def hr_plugin_enabled?
				Setting.plugin_redmine_bsc["plugin_hr"]
				true
			end

			def ie_plugin_enabled?
				Setting.plugin_redmine_bsc["plugin_ie"]
				true
			end

			def get_profiles
				self.hr_plugin_enabled? ? HrProfile.all : [] #.map(&:name) : []
		  	end

		  	def get_income_trackers
		  		self.ie_plugin_enabled? ? IeVariableIncome.all.map(&:tracker) : []
		  	end

		  	def get_expense_trackers
		  		self.ie_plugin_enabled? ? (IeVariableExpense.all + IeFixedExpense.all).map(&:tracker) : []
		  	end

		  	def get_incomes_issues(projects = nil, start_date, end_date)
		  		if self.ie_plugin_enabled?
		  			find_income_expenses(IeVariableIncome.all, projects, start_date, end_date)
		  			#projects ? ie.issues.includes(:ie_income_expenses).joins("LEFT JOIN custom_values AS end_date ON end_date.customized_id = issues.id AND end_date.custom_field_id = #{ie.end_date_field}").where("project_id IN (?) AND created_on BETWEEN ? AND ?", projects, start_date, end_date).select("issues.*, end_date.value AS scheduled_date")
					# projects ? ie.issues.includes(:ie_income_expenses, :custom_values).where("project_id IN (?) AND created_on BETWEEN ? AND ?", projects, start_date, end_date).select("issues.*, custom_values.value AS scheduled_date") : ie.issues
				else
					[]
				end
		  	end

		  	def get_expenses_issues(projects = nil, start_date, end_date)
		  		# self.ie_plugin ? 
		  		# 	(IeVariableExpense.all + IeFixedExpense.all).map{|ie| 
		  		# 		projects ? ie.issues.includes(:ie_income_expenses, :custom_values).where("project_id IN (?) AND created_on BETWEEN ? AND ?", projects, start_date, end_date).select("issues.*, issues.#{ie.start_date_field} AS scheduled_date") : ie.issues
		  		# 	}.flatten : 
		  		# 	[]
		  		if self.ie_plugin_enabled?
		  			find_income_expenses((IeVariableExpense.all + IeFixedExpense.all), projects, start_date, end_date)
		  		else
		  			[]
				end
		  	end

		  	def get_income_expenses_issues(projects = nil, start_date, end_date)
		  		if self.ie_plugin_enabled?
		  			find_income_expenses((IeVariableIncome.all + IeVariableExpense.all + IeFixedExpense.all), projects, start_date, end_date)
		  		else
		  			[]
				end
		  	end

		  	def get_hourly_cost(profile_id, year = Date.today.year)
		  		(hr_plugin_enabled? and profile_id != 0) ? HrProfile.find(profile_id).cost_on(year) : 0.0
		  	end

		  	def get_hourly_cost_array(year = Date.today.year)
		  		hr_plugin_enabled? ? HrProfilesCost.where(year: year).inject({}){|sum, pc| sum.merge({pc.hr_profile_id => pc.hourly_cost.to_f}) } : Hash.new(0.0)
		  	end

		  	private
		 #  	def find_income_expenses(income_expenses_type, project, start_date, end_date)
		 #  		result = []
		 #  		income_expenses_type.each do |ie| 
		 #  			joins = "LEFT JOIN custom_values AS amount ON amount.customized_id = issues.id AND amount.custom_field_id = #{ie.amount_field_id} "+
		 #  				"LEFT JOIN journals ON journals.journalized_type = 'Issue' AND journals.journalized_id = issues.id AND DATE(journals.created_on) = #{date} "
		 #  			#select = "issues.*, '#{ie.class.name}' AS type, amount.value AS amount"
		 #  			where = "issues.project_id = #{project} "

		 #  			if is_number?(ie.start_date_field)
		 #  				joins += "LEFT JOIN custom_values AS start_date ON start_date.customized_id = issues.id AND start_date.custom_field_id = #{ie.start_date_field} "
		 #  				select += ", start_date.value AS scheduled_date" 
		 #  			else
		 #  				select += ", issues.#{ie.start_date_field} AS scheduled_date"
		 #  			end

		 #  			if is_number?(ie.end_date_field)
		 #  				joins += "LEFT JOIN custom_values AS end_date ON end_date.customized_id = issues.id AND end_date.custom_field_id = #{ie.end_date_field} "
		 #  				select += ", end_date.value AS incurred_date" 
		 #  			else
		 #  				select += ", issues.#{ie.end_date_field} AS incurred_date"
		 #  			end

		 #  			Issues.joins(:journals).where("issues.project_id = ? AND DATE(journals.created_on) = ?", project, date)

			# 		result << (projects ? 
			# 			ie.issues.includes(:ie_income_expenses).joins(joins).where("project_id IN (?) AND created_on BETWEEN ? AND ?", projects, start_date, end_date).select(select) : 
			# 			ie.issues.includes(:ie_income_expenses).joins(joins).where("created_on BETWEEN ? AND ?", start_date, end_date).select(select))
			# 	end

			# 	result.flatten
		 #  	end

		 #  	def find_income_expenses(income_expenses_types, project, date)
		 #  		result = []
		 #  		income_expenses_types.each do |ie| 
		 #  			joins = "LEFT JOIN custom_values AS amount ON amount.customized_id = issues.id AND amount.custom_field_id = #{ie.amount_field_id} "
		 #  			select = "issues.*, '#{ie.class.name}' AS type, amount.value AS amount"

		 #  			if is_number?(ie.start_date_field)
		 #  				joins += "LEFT JOIN custom_values AS start_date ON start_date.customized_id = issues.id AND start_date.custom_field_id = #{ie.start_date_field} "
		 #  				select += ", start_date.value AS scheduled_date" 
		 #  			else
		 #  				select += ", issues.#{ie.start_date_field} AS scheduled_date"
		 #  			end

		 #  			if is_number?(ie.end_date_field)
		 #  				joins += "LEFT JOIN custom_values AS end_date ON end_date.customized_id = issues.id AND end_date.custom_field_id = #{ie.end_date_field} "
		 #  				select += ", end_date.value AS incurred_date" 
		 #  			else
		 #  				select += ", issues.#{ie.end_date_field} AS incurred_date"
		 #  			end

			# 		result << (projects ? 
			# 			ie.issues.includes(:ie_income_expenses).joins(joins).where("project_id IN (?) AND created_on BETWEEN ? AND ?", projects, start_date, end_date).select(select) : 
			# 			ie.issues.includes(:ie_income_expenses).joins(joins).where("created_on BETWEEN ? AND ?", start_date, end_date).select(select))
			# 	end

			# 	result.flatten
		 #  	end

		 #  	def is_number?(string)
			#   true if Float(string) rescue false
			# end
		end
	end
end