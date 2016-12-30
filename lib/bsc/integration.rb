module BSC
	class Integration
		class << self
			def hr_plugin_enabled?
				Setting.plugin_redmine_bsc["plugin_hr"]
			end

			def ie_plugin_enabled?
				Setting.plugin_redmine_bsc["plugin_ie"]
			end

			def currency_plugin_enabled?
				Setting.plugin_redmine_bsc["plugin_currency"]
			end

			def get_profiles
				self.hr_plugin_enabled? ? HrProfile.all : [] #.map(&:name) : []
		  	end

		  	def get_variable_incomes
		  		self.ie_plugin_enabled? ? IeVariableIncome.all : []
		  	end

		  	def get_variable_expenses
		  		self.ie_plugin_enabled? ? IeVariableExpense.all : []
		  	end

		  	def get_fixed_expenses
		  		self.ie_plugin_enabled? ? IeFixedExpense.all : []
		  	end

		  	def get_expense_trackers
		  		self.ie_plugin_enabled? ? (IeVariableExpense.all + IeFixedExpense.all).map(&:tracker) : []
		  	end

		  	def get_income_trackers
		  		self.ie_plugin_enabled? ? IeVariableIncome.all.map(&:tracker) : []
		  	end

		  	def get_expense_trackers
		  		self.ie_plugin_enabled? ? (IeVariableExpense.all + IeFixedExpense.all).map(&:tracker) : []
		  	end

		  	def get_hourly_cost(profile_id, year = Date.today.year)
		  		(hr_plugin_enabled? and profile_id != 0) ? HrProfile.find(profile_id).cost_on(year) : 0.0
		  	end

		  	def get_hourly_cost_array(year = Date.today.year)
		  		hr_plugin_enabled? ? HrProfilesCost.where(year: year).inject({}){|sum, pc| sum.merge({pc.hr_profile_id => pc.hourly_cost.to_f}) } : Hash.new(0.0)
		  	end

		  	# Currency plugin
		  	def get_default_currency
		  		self.currency_plugin_enabled? ? Currency.default_currency : nil
		  	end

		  	def get_currencies
		  		self.currency_plugin_enabled? ? Currency.all : []
		  	end

		  	def get_currency(currency)
		  		self.currency_plugin_enabled? ? Currency.find(currency) : nil
		  	end
		end
	end
end