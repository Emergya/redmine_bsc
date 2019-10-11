module BSC
	class Metrics
		def initialize(project, date = Date.today, args = {})
			default_args = {:descendants => true}
			args = args.is_a?(Hash) ? default_args.merge(args) : default_args

			@hr_plugin = BSC::Integration.hr_plugin_enabled?
			@ie_plugin = BSC::Integration.ie_plugin_enabled?
			@date = date
			@projects = args[:descendants] ? Array(Project.find(project).self_and_descendants.active) : Array(Project.find(project))

			@projects = @projects.select{|p| (args[:white_list]+[project]).include?(p.id)} if args[:white_list].present?
			@projects = @projects.reject{|p| (args[:black_list]-[project]).include?(p.id)} if args[:black_list].present?
		end

# HHRR Hours
		def hhrr_hours_scheduled
			@hhrr_hours_scheduled ||= 
			(begin
				result = 0.0
				@projects.each do |project|
					if (last_checkpoint = project.last_checkpoint(@date)).present?
						result += last_checkpoint.bsc_checkpoint_efforts.sum(:scheduled_effort) 
					end
				end
				result
			rescue
				0.0
			end)
		end

		def all_hhrr_hours_scheduled_by_profile
			@all_hhrr_hours_scheduled_by_profile ||= 
			(if @hr_plugin
				result = Hash.new(0.0)
				@projects.each do |project|
					if (last_checkpoint = project.last_checkpoint(@date)).present?
						last_checkpoint.scheduled_profile_effort_hash.each do |profile_id,hours|
							result[profile_id] += hours
						end
					end
				end
				result
			else
				{}
			end)
		end

		def hhrr_hours_scheduled_by_profile
			all_hhrr_hours_scheduled_by_profile
		end

		def hhrr_hours_incurred
			@hhrr_hours_incurred ||= TimeEntry.where('project_id IN (?) AND spent_on <= ?', @projects.map(&:id), @date).sum(:hours)
		end

		def all_hhrr_hours_incurred_by_profile
			@all_hhrr_hours_incurred_by_profile ||=
			(if @hr_plugin
				result = Hash.new(0.0)
				TimeEntry.where('project_id IN (?) AND spent_on <= ?', @projects.map(&:id), @date).each do |te|
					result[te.hr_profile_id] += te.hours
				end
				result
			else
				{}
			end)
		end

		def hhrr_hours_incurred_by_profile
			all_hhrr_hours_incurred_by_profile
		end

		def hhrr_hours_remaining
			@hhrr_hours_remaining ||= hhrr_hours_scheduled - hhrr_hours_incurred
		end

		def hhrr_hours_remaining_by_profile
			@hhrr_hours_remaining_by_profile ||=
			(if @hr_plugin
				scheduled = Hash.new(0.0).merge(hhrr_hours_scheduled_by_profile)
				incurred = Hash.new(0.0).merge(hhrr_hours_incurred_by_profile)
				result = {}
				(scheduled.keys + incurred.keys).each do |profile|
					result[profile] = scheduled[profile] - incurred[profile]
				end
				result
			else
				{}
			end)
		end

# HHRR Cost
		def hhrr_cost_scheduled_remaining
			#@hhrr_cost_scheduled_remaining ||=
			(hourly_cost_by_profile = Hash.new(0.0).merge(BSC::Integration.get_hourly_cost_array(@date.year))
			hours_incurred_by_profile = Hash.new(0.0).merge(all_hhrr_hours_incurred_by_profile)
			total = 0.0
			all_hhrr_hours_scheduled_by_profile.each do |profile, effort|
				# Si hay más horas incurridas que estimadas para un perfil, se considera estimadas = incurridas para ese perfil
				total += (effort - hours_incurred_by_profile[profile]) * hourly_cost_by_profile[profile]
			end
			total) 
		end

		def hhrr_cost_scheduled_remaining_by_profile
			(hourly_cost_by_profile = Hash.new(0.0).merge(BSC::Integration.get_hourly_cost_array(@date.year))
			hours_incurred_by_profile = Hash.new(0.0).merge(all_hhrr_hours_incurred_by_profile)
			result = Hash.new(0.0)
			all_hhrr_hours_scheduled_by_profile.each do |profile, effort|
				# Si hay más horas incurridas que estimadas para un perfil, se considera estimadas = incurridas para ese perfil
				result[profile] += (effort - hours_incurred_by_profile[profile]) * hourly_cost_by_profile[profile]
			end
			result) 
		end

		def hhrr_cost_scheduled
			@hhrr_cost_scheduled ||= 
			(total = hhrr_cost_incurred
			scheduled_remaining = hhrr_cost_scheduled_remaining

			if scheduled_remaining > 0
				total = total + scheduled_remaining
			end
			
			total)
		end

		def hhrr_cost_scheduled_by_profile
			@hhrr_cost_scheduled_by_profile ||= 
			(if @hr_plugin
				result = hhrr_cost_incurred_by_profile
				scheduled_remaining = hhrr_cost_scheduled_remaining_by_profile

				scheduled_remaining.each do |profile, effort|
					if effort > 0
						result[profile] += effort
					end
				end
				result
			else
				{}
			end)
		end

		def hhrr_cost_scheduled_checkpoint
			(hourly_cost_by_profile = Hash.new(0.0).merge(BSC::Integration.get_hourly_cost_array(@date.year))
			total = 0.0
			hhrr_hours_scheduled_by_profile.each do |profile, effort|
				total += effort * hourly_cost_by_profile[profile]
			end
			total) 
		end

		def hhrr_cost_incurred
			@hhrr_cost_incurred ||= 
			(if @hr_plugin
				TimeEntry.where('project_id IN (?) AND spent_on <= ?', @projects.map(&:id), @date).sum(:cost)
			else
				0.0
			end)
		end

		def hhrr_cost_incurred_by_profile
			@hhrr_cost_incurred_by_profile ||= 
			(if @hr_plugin
				result = Hash.new(0.0)
				TimeEntry.where('project_id IN (?) AND spent_on <= ?', @projects.map(&:id), @date).each do |te|
					result[te.hr_profile_id] += te.cost
				end
				result
			else
				{}
			end)
		end

		def hhrr_cost_remaining
			@hhrr_cost_remaining ||= hhrr_cost_scheduled - hhrr_cost_incurred
		end



# Variable Income
		def variable_income_scheduled
			@variable_income_scheduled ||=
			BSC::Integration.get_variable_incomes.inject(0.0){|sum, ie|
				sum += 
					ie.issues_scheduled(@projects.map(&:id), @date).sum{|i| i.amount.to_f}
			}
		end

		def variable_income_scheduled_by_tracker
			@variable_income_scheduled_by_tracker ||=
			BSC::Integration.get_variable_incomes.inject({}){|sum, ie|
				sum.merge({ie.tracker[:name] => 
					ie.issues_scheduled(@projects.map(&:id), @date).sum{|i| i.amount.to_f} 
				})
			}
		end

		def variable_income_incurred
			@variable_income_incurred ||=
			BSC::Integration.get_variable_incomes.inject(0.0){|sum, ie|
				sum += ie.issues_incurred(@projects.map(&:id), @date).sum{|i| i.amount.to_f}
			}
		end

		def variable_income_incurred_by_tracker
			@variable_income_incurred_by_tracker ||=
			BSC::Integration.get_variable_incomes.inject({}){|sum, ie|
				sum.merge({ie.tracker[:name] => 
					ie.issues_incurred(@projects.map(&:id), @date).sum{|i| i.amount.to_f} 
				})
			}
		end

		def variable_income_remaining
			@variable_income_remaining ||= variable_income_scheduled - variable_income_incurred
		end



# Variable Expense
		def variable_expense_scheduled
			@variable_expense_scheduled ||=
			BSC::Integration.get_variable_expenses.inject(0.0){|sum, ie|
				sum += ie.issues_scheduled(@projects.map(&:id), @date).sum{|i| i.amount.to_f}
			}
		end

		def variable_expense_scheduled_by_tracker
			@variable_expense_scheduled_by_tracker ||= 
			BSC::Integration.get_variable_expenses.inject({}){|sum, ie|
				sum.merge({ie.tracker[:name] => 
					ie.issues_scheduled(@projects.map(&:id), @date).sum{|i| i.amount.to_f}
				})
			}
		end

		def variable_expense_incurred
			@variable_expense_incurred ||= 
			BSC::Integration.get_variable_expenses.inject(0.0){|sum, ie|
				sum += ie.issues_incurred(@projects.map(&:id), @date).sum{|i| i.amount.to_f}
			}
		end

		def variable_expense_incurred_by_tracker
			@variable_expense_incurred_by_tracker ||= 
			BSC::Integration.get_variable_expenses.inject({}){|sum, ie|
				sum.merge({ie.tracker[:name] => 
					ie.issues_incurred(@projects.map(&:id), @date).sum{|i| i.amount.to_f}
				})
			}
		end

		def variable_expense_remaining
			@variable_expense_remaining ||= variable_expense_scheduled - variable_expense_incurred
		end


# Fixed Expense
		def fixed_expense_scheduled
			@fixed_expense_scheduled ||=
			BSC::Integration.get_fixed_expenses.inject(0.0){|sum, ie|
				sum += 
					ie.issues_scheduled(@projects.map(&:id), @date).sum{|i| i.amount.to_f}
			}
		end

		def fixed_expense_scheduled_by_tracker
			@fixed_expense_scheduled_by_tracker ||= 
			BSC::Integration.get_fixed_expenses.inject({}){|sum, ie|
				sum.merge({ie.tracker[:name] => 
					ie.issues_scheduled(@projects.map(&:id), @date).sum{|i| i.amount.to_f}
				})
			}
		end

		# solo para start_date y end_date de tipo 'attr'
		def fixed_expense_incurred
			@fixed_expense_incurred ||=
			(result = 0.0
			BSC::Integration.get_fixed_expenses.each do |ie|
				ie.issues_scheduled(@projects.map(&:id), @date).each do |i|
					start_date = (Date.parse(i.historic_value(@date)['start_date']) rescue i.historic_value(@date)['start_date'])
					end_date = (Date.parse(i.historic_value(@date)['due_date']) rescue i.historic_value(@date)['due_date'])
					amount = (i.historic_value(@date)['amount'].to_f) rescue i.historic_value(@date)['amount']
					
					if start_date.present? and end_date.present? and amount.present?
						incurred_end_date = [@date, end_date].min
					
						result += amount * (incurred_end_date - start_date + 1).to_f / (end_date - start_date + 1).to_f if incurred_end_date >= start_date
					end
				end
			end
			result)
		end

		def fixed_expense_incurred_by_tracker
			@fixed_expense_incurred_by_tracker ||=
			(result = {}
			BSC::Integration.get_fixed_expenses.each do |ie|
				subresult = 0
				result[ie.tracker[:name]] = (ie.issues_scheduled(@projects.map(&:id), @date).each do |i|
					start_date = (Date.parse(i.historic_value(@date)['start_date']) rescue i.historic_value(@date)['start_date'])
					end_date = (Date.parse(i.historic_value(@date)['due_date']) rescue i.historic_value(@date)['due_date'])
					amount = (i.historic_value(@date)['amount'].to_f) rescue i.historic_value(@date)['amount']

					if start_date.present? and end_date.present? and amount.present?
						incurred_end_date = [@date, end_date].min
					
						subresult += amount * (incurred_end_date - start_date + 1).to_f / (end_date - start_date + 1).to_f if incurred_end_date >= start_date
					end
				end
				subresult)			
			end
			result)
		end

		def fixed_expense_remaining
			@fixed_expense_remaining ||= fixed_expense_scheduled - fixed_expense_incurred
		end


# Total income
		def total_income_scheduled
			@total_income_scheduled ||= variable_income_scheduled
		end

		def total_income_scheduled_by_concept
			@total_income_scheduled_by_concept ||= variable_income_scheduled_by_tracker
		end

		def total_income_incurred
			@total_income_incurred ||= variable_income_incurred
		end

		def total_income_incurred_by_concept
			@total_income_incurred_by_concept ||= variable_income_incurred_by_tracker
		end

		def total_income_remaining
			@total_income_remaining ||= total_income_scheduled - total_income_incurred
		end


# Total Expense
		def total_expense_scheduled
			@total_expense_scheduled ||= hhrr_cost_scheduled + variable_expense_scheduled + fixed_expense_scheduled
		end

		def total_expense_scheduled_by_concept
			@total_expense_scheduled_by_concept ||= [{"RRHH" => hhrr_cost_scheduled}, variable_expense_scheduled_by_tracker, fixed_expense_scheduled_by_tracker].reduce(&:merge)
		end

		def total_expense_incurred
			@total_expense_incurred ||= hhrr_cost_incurred + variable_expense_incurred + fixed_expense_incurred
		end

		def total_expense_incurred_by_concept
			@total_expense_incurred_by_concept ||= [{"RRHH" => hhrr_cost_incurred}, variable_expense_incurred_by_tracker, fixed_expense_incurred_by_tracker].reduce(&:merge)
		end

		def total_expense_remaining
			@total_expense_remaining ||= total_expense_scheduled - total_expense_incurred
		end

		
# Others
		def scheduled_margin
			@scheduled_target ||= 100.0 * (total_income_scheduled - total_expense_scheduled) / total_income_scheduled.abs
		end

		def margin_target
			@margin_target ||= 
			(if @projects.count == 1
				if (last_checkpoint = @projects.first.last_checkpoint(@date)).present?
					res = (100.0 * (last_checkpoint.target_incomes - last_checkpoint.target_expenses) / last_checkpoint.target_incomes.abs)
					!res.nan? ? res : 0.0
				else
					0.0
				end
			else
				total_target_incomes = 0.0
				total_target_expenses = 0.0
				@projects.each do |p|
					if (aux_last_checkpoint = p.last_checkpoint(@date)).present?
						total_target_incomes += aux_last_checkpoint.target_incomes
						total_target_expenses += aux_last_checkpoint.target_expenses
					else
						total_target_incomes += 0.0
						total_target_expenses += 0.0
					end
				end
				res = (total_target_incomes != 0.0) ? (100.0 * (total_target_incomes - total_target_expenses) / total_target_incomes.abs) : 0.0
				!res.nan? ? res : 0.0
			end)
		end

		def scheduled_finish_date
			@scheduled_finish_date ||= @projects.reject{|p| p.bsc_info.blank?}.map{|p| p.last_checkpoint(@date) || p.bsc_info}.reject{|c| c.blank?}.map(&:scheduled_finish_date).reject{|date| date.blank?}.max
		end

		def scheduled_start_date
			@scheduled_start_date ||= @projects.reject{|p| p.bsc_info.blank?}.map{|p| p.bsc_info.scheduled_start_date}.reject{|date| date.blank?}.min
		end

		def real_finish_date
        	@real_finish_date ||= 
        	(end_date_by_planned_end_date = []
        	(BSC::Integration.get_expense_trackers + BSC::Integration.get_income_trackers).each do |tracker|
        		if tracker.ie_income_expense.planned_end_field_type == "attr"
	        		planned_end_date = tracker.ie_income_expense.planned_end_date_field.to_s
        			@projects.each do |p|
						end_date_by_planned_end_date += p.issues.where(tracker_id: tracker.id).map{|i| i[planned_end_date].present? ? i[planned_end_date] : nil}
					end 
        		else
					planned_end_date = tracker.ie_income_expense.planned_end_date_field.to_i
					@projects.each do |p|
						end_date_by_planned_end_date += p.issues.where(tracker_id: tracker.id).map{|i| i.custom_value_for(planned_end_date).present? ? i.custom_value_for(planned_end_date).value : nil}
					end
				end
			end
			end_date_by_planned_end_date = end_date_by_planned_end_date.compact.present? ? end_date_by_planned_end_date.compact.map(&:to_date).max : nil

			end_date_by_time_entries = @projects.map{|p| p.time_entries.maximum(:spent_on)}.compact.max
			end_date_by_issues = @projects.map{|p| p.issues.maximum(:created_on)}.compact.max

        	[end_date_by_time_entries, end_date_by_issues, end_date_by_planned_end_date, scheduled_finish_date].compact.max.to_date rescue Date.today)
		end

		def real_start_date
			@real_start_date ||= 
			(start_date_by_planned_start_date = []
			(BSC::Integration.get_expense_trackers + BSC::Integration.get_income_trackers).each do |tracker|
				if tracker.ie_income_expense.start_field_type == "attr"
	        		start_date_field = tracker.ie_income_expense.start_date_field.to_s
        			@projects.each do |p|
						start_date_by_planned_start_date += p.issues.where(tracker_id: tracker.id).map{|i| i[start_date_field].present? ? i[start_date_field] : nil}
					end 
        		else
					start_date_field = tracker.ie_income_expense.start_date_field.to_i
					@projects.each do |p|
						start_date_by_planned_start_date += p.issues.where(tracker_id: tracker.id).map{|i| i.custom_value_for(start_date_field).present? ? i.custom_value_for(start_date_field).value : nil}
					end
				end
			end
			start_date_by_planned_start_date = start_date_by_planned_start_date.compact.present? ? start_date_by_planned_start_date.compact.map(&:to_date).min : nil

			start_date_by_time_entries = @projects.map{|p| p.time_entries.minimum(:spent_on)}.compact.min
			start_date_by_time_entries = start_date_by_time_entries.present? ? start_date_by_time_entries - 1.day : start_date_by_time_entries
			start_date_by_issues = @projects.map{|p| p.issues.minimum(:created_on)}.compact.min

     		[start_date_by_time_entries, start_date_by_issues, start_date_by_planned_start_date, scheduled_start_date].compact.min.to_date rescue @projects.map(&:created_on).min.to_date)
		end

		def expenses_target
			@expenses_target ||=
			(if @projects.count == 1
				# if (last_checkpoint = @projects.first.last_checkpoint(@date)).present?
				if (last_checkpoint = @projects.first.real_last_checkpoint).present?
					last_checkpoint.target_expenses.round(2)
				else
					0.0
				end
			else
				result = 0.0
				@projects.each do |p|
					aux_metric = Metrics.new(p, @date, {:descendants => false})
					result += aux_metric.expenses_target
				end
				result.round(2)
			end)
		end

		def incomes_target
			@incomes_target ||=
			(if @projects.count == 1
				# if (last_checkpoint = @projects.first.last_checkpoint(@date)).present?
				if (last_checkpoint = @projects.first.real_last_checkpoint).present?
					last_checkpoint.target_incomes.round(2)
				else
					0.0
				end
			else
				result = 0.0
				@projects.each do |p|
					aux_metric = Metrics.new(p, @date, {:descendants => false})
					result += aux_metric.incomes_target
				end
				result.round(2)
			end)
		end
	end
end