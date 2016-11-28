module BSC
	class Metrics
		def initialize(project, date = Date.today, args = {})
			default_args = {:descendants => true}
			args = args.is_a?(Hash) ? default_args.merge(args) : default_args

			@hr_plugin = BSC::Integration.hr_plugin_enabled?
			@ie_plugin = BSC::Integration.ie_plugin_enabled?
			@date = date
			@projects = args[:descendants] ? Array(Project.find(project).self_and_descendants) : Array(Project.find(project))
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

		def hhrr_hours_scheduled_by_profile
			@hhrr_hours_scheduled_by_profile ||= 
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

		def hhrr_hours_incurred
			@hhrr_hours_incurred ||= TimeEntry.where('project_id IN (?) AND spent_on <= ?', @projects.map(&:id), @date).sum(:hours)
		end

		def hhrr_hours_incurred_by_profile
			@hhrr_hours_incurred_by_profile ||=
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
		def hhrr_cost_scheduled
			@hhrr_cost_scheduled ||= 
			(hourly_cost_by_profile = Hash.new(0.0).merge(BSC::Integration.get_hourly_cost_array(@date.year))
			hours_incurred_by_profile = Hash.new(0.0).merge(hhrr_hours_incurred_by_profile)

			total = hhrr_cost_incurred
			subtotal = 0.0
			hhrr_hours_scheduled_by_profile.each do |profile, effort|
				# Si hay más horas incurridas que estimadas para un perfil, se considera estimadas = incurridas para ese perfil
				subtotal += (effort - hours_incurred_by_profile[profile]) * hourly_cost_by_profile[profile]
			end
			if subtotal > 0
				total = total + subtotal
			end
			total)
		end

		# def hhrr_cost_scheduled_by_profile
		# end

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
				sum.merge({ie.tracker.name => 
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
				sum.merge({ie.tracker.name => 
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
				sum.merge({ie.tracker.name => 
					ie.issues_scheduled(@projects.map(&:id), @date).sum{|i| i.amount.to_f}
				})
			}
		end

		# solo para start_date y end_date de tipo 'attr'
		def fixed_expense_incurred
			@fixed_expense_incurred ||=
			(result = 0.0
			BSC::Integration.get_fixed_expenses.each do |ie|
				ie.issues_incurred(@projects.map(&:id), @date).each do |i|
					start_date = i.historic_value(@date)['start_date']
					end_date = i.historic_value(@date)['due_date']
					incurred_end_date = [@date, end_date].min
					amount = i[:amount].to_f

					result += amount * (incurred_end_date - start_date).to_f / (end_date - start_date).to_f if incurred_end_date >= start_date
				end
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

		def total_expense_remaining
			@total_expense_remaining ||= total_expense_scheduled - total_expense_incurred
		end

		
# Others
		def scheduled_margin
			@scheduled_target ||= 100.0 * (total_income_scheduled - total_expense_scheduled) / total_income_scheduled
		end

		def margin_target
			@margin_target ||= 
			(if @projects.count == 1
				if (last_checkpoint = @projects.first.last_checkpoint(@date)).present?
					last_checkpoint.target_margin
				else
					0.0
				end
			else
				projects = 0.0
				result = 0.0
				@projects.each do |project|
					if (last_checkpoint = project.last_checkpoint(@date)).present?
						projects += 1
						result += last_checkpoint.target_margin
					end
				end
				(result/projects)
			end)
		end

		def scheduled_finish_date
			@scheduled_finish_date ||= @projects.reject{|p| p.bsc_info.blank?}.map{|p| p.last_checkpoint(@date) || p.bsc_info}.reject{|c| c.blank?}.map(&:scheduled_finish_date).reject{|date| date.blank?}.max
		end

		def scheduled_start_date
			@scheduled_start_date ||= @projects.reject{|p| p.bsc_info.blank?}.map{|p| p.bsc_info.scheduled_start_date}.reject{|date| date.blank?}.min
		end
	end
end