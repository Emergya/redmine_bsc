class BscMetricsController < ApplicationController
	before_filter :find_project_by_project_id, :authorize

	menu_item :bsc
	helper :bsc

	def index
	end
end