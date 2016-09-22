module BSC
	class Integration
		class << self
			def hr_plugin
				Setting.plugin_redmine_bsc["plugin_hr"]
			end

			def ie_plugin
				Setting.plugin_redmine_bsc["plugin_ie"]
			end

			def get_profiles
				self.hr_plugin ? HrProfile.all : [] #.map(&:name) : []
		  end
		end
	end
end