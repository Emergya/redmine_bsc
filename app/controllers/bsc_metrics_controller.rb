class BscMetricsController < ApplicationController
	before_filter :find_project_by_project_id, :authorize#, :except => [:change_metric]

	menu_item :bsc
	helper :bsc

	# def index
	# 	#widget = BSC::Widgets::Effort.new([452, 461, 353, 391, 310, 494, 398])
	# 	widget = BSC::Widgets::Margin.new(@project.self_and_descendants.map(&:id), Date.parse('2012-10-01'), Date.parse('2016-10-05'))
	# 	# widget = BSC::Widgets::Effort.new(@project.self_and_descendants.map(&:id), Date.parse('2015-01-01'), Date.parse('2016-09-01'))
	# 	@chart_name = widget.name
	# 	@chart_data = widget.content_data.to_json
	# end

	# def show_metric
	# 	if params[:name]
	# 		BSC::Metrics::Margin
	# 	end
	# end

	def index
		#@metrics = BSC::Metrics.new(@project, Date.today)
		@metric_options = ['mc', 'effort', 'income_expenses', 'time_entries']

		load_headers
		change_metric
	end

	def load_headers
		@metric_options.each do |metric_option|
			case metric_option
			when 'mc'
				@mc_header = BscMc.get_header(@project)
			when 'effort'
				@effort_header = BscEffort.get_header(@project)
			when 'income_expenses'
				@income_expenses_header = BscIncomeExpense.get_header(@project)
			when 'deliverable'
			when 'time_entries'
			end
		end
	end

	def change_metric
		@metric_selected = params[:type] || @metric_options.first
		case @metric_selected
		when 'mc'
			# data = BscMc.get_data(@project.id, Date.parse('2014-05-10'), Date.today)
			data = BscMc.get_data(@project.id, Date.today)
			@table_data = data[:chart]
			@chart_data = data[:chart].to_json
			@scheduled_margin = data[:scheduled_margin]
			@target_margin = data[:target_margin]
			# @incomes_cols = BSC::Integration.get_income_trackers.map{|t| {t[:id] => t[:name]} }.reduce(&:merge)
			# @expenses_cols = BSC::Integration.get_expense_trackers.map{|t| {t[:id] => t[:name]} }.reduce(&:merge).merge({:nil => 'RRHH'})
			@incomes_trackers = BSC::Integration.get_income_trackers
			@expenses_trackers = BSC::Integration.get_expense_trackers
			@hhrr_name = 'RRHH'
		when 'effort'
			# data = BscEffort.get_data(@project.id, Date.parse('2014-05-10'), Date.today)
			data = BscEffort.get_data(@project.id, Date.today)
			@chart_data = data[:chart]
			@table_data = data[:table]
		when 'income_expenses'
			data = BscIncomeExpense.get_data(@project.id)
			@income_table = data[:incomes]
			@expense_table = data[:expenses]
		when 'deliverable'
		when 'time_entries'
			data = BscTimeEntry.get_data(@project.id)
			@table_members = data[:members]
			@table_profiles = data[:profiles]
			@profile_names = data[:profile_names]
		end

		if request.xhr?
          render :json => { :filter => render_to_string(:partial => 'bsc_metrics/metrics/'+@metric_selected, :layout => false) }
        end
	end
end

