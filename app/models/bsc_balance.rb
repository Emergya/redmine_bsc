class BscBalance < ActiveRecord::Base
	# Get balance content data
	def self.get_data(project)
		{}
	end

	# Get balance header data
	def self.get_header(project)
		{:status => 'metric_success', :result => 'X'}
	end	
end