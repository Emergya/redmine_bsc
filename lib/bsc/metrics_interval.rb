module BSC
	class MetricsInterval < Metrics
		def initialize(project, start_date, end_date = Date.today, args = {})
			super(project, end_date, args)

			@start_date = start_date
			@end_date = end_date
		end

# HHRR Hours
		def hhrr_hours_scheduled
			@hhrr_hours_scheduled ||= 
			(begin
				super * ([@end_date, scheduled_finish_date, Date.today].min - [@start_date, scheduled_start_date].max) / (scheduled_finish_date - scheduled_start_date)
			rescue
				0.0
			end)
		end

		def hhrr_hours_scheduled_by_profile
			@hhrr_hours_scheduled_by_profile ||= 
			(begin
				result = {}
				super.each do |profile, hours|
					result[profile] = hours * ([@end_date, scheduled_finish_date, Date.today].min - [@start_date, scheduled_start_date].max) / (scheduled_finish_date - scheduled_start_date)
				end
				result
			rescue
				{}
			end)
		end

		def hhrr_hours_incurred
			@hhrr_hours_incurred ||= TimeEntry.where('project_id IN (?) AND spent_on BETWEEN ? AND ?', @projects.map(&:id), @start_date, @end_date).sum(:hours)
		end

		def hhrr_hours_incurred_by_profile
			@hhrr_hours_incurred_by_profile ||=
			(if @hr_plugin
				result = Hash.new(0.0)
				TimeEntry.where('project_id IN (?) AND spent_on BETWEEN ? AND ?', @projects.map(&:id), @start_date, @end_date).each do |te|
					result[te.hr_profile_id] += te.hours
				end
				result
			else
				Hash.new(0.0)
			end)
		end


# HHRR Cost
		def hhrr_cost_scheduled
			@hhrr_cost_scheduled ||=
			(if @end_date < Date.today or scheduled_finish_date < Date.today
				hhrr_cost_incurred
			elsif scheduled_finish_date >= @start_date
				scheduled_remaining = hhrr_cost_scheduled_remaining
				if scheduled_remaining > 0
					hhrr_cost_incurred + (scheduled_remaining * ([@end_date, scheduled_finish_date].min - [@start_date, Date.today].max + 1) / (scheduled_finish_date - Date.today + 1))
				else
					hhrr_cost_incurred
				end
			else
				0.0
			end)
		end

		def hhrr_cost_incurred
			@hhrr_cost_incurred ||= 
			(if @hr_plugin
				TimeEntry.where('project_id IN (?) AND spent_on BETWEEN ? AND ?', @projects.map(&:id), @start_date, @end_date).sum(:cost)
			else
				0.0
			end)
		end

		def hhrr_cost_incurred_by_profile
			@hhrr_cost_incurred_by_profile ||= 
			(if @hr_plugin
				result = Hash.new(0.0)
				TimeEntry.where('project_id IN (?) AND spent_on BETWEEN ? AND ?', @projects.map(&:id), @start_date, @end_date).each do |te|
					result[te.hr_profile_id] += te.cost
				end
				result
			else
				Hash.new(0.0)
			end)
		end



# Variable Income
		def variable_income_scheduled
			@variable_income_scheduled ||= 
			BSC::Integration.get_variable_incomes.inject(0.0){|sum, ie|
				sum += ie.issues_scheduled_interval(@projects.map(&:id), @start_date, @end_date).sum{|i| i.amount.to_f}
			}
		end

		def variable_income_scheduled_by_tracker
			@variable_income_scheduled_by_tracker ||= 
			BSC::Integration.get_variable_incomes.inject({}){|sum, ie|
				sum.merge({ie.tracker[:name] => 
					ie.issues_scheduled_interval(@projects.map(&:id), @start_date, @end_date).sum{|i| i.amount.to_f}
				})
			}
		end

		def variable_income_incurred
			@variable_income_incurred ||= 
			BSC::Integration.get_variable_incomes.inject(0.0){|sum, ie|
				sum += ie.issues_incurred_interval(@projects.map(&:id), @start_date, @end_date).sum{|i| i.amount.to_f}
			}
		end

		def variable_income_incurred_by_tracker
			@variable_income_incurred_by_tracker ||= 
			BSC::Integration.get_variable_incomes.inject({}){|sum, ie|
				sum.merge({ie.tracker[:name] => 
					ie.issues_incurred_interval(@projects.map(&:id), @start_date, @end_date).sum{|i| i.amount.to_f}
				})
			}
		end

# Variable Expense
		def variable_expense_scheduled
			@variable_expense_scheduled ||= 
			BSC::Integration.get_variable_expenses.inject(0.0){|sum, ie|
				sum += ie.issues_scheduled_interval(@projects.map(&:id), @start_date, @end_date).sum{|i| i.amount.to_f}
			}
		end

		def variable_expense_scheduled_by_tracker
			@variable_expense_scheduled_by_tracker ||= 
			BSC::Integration.get_variable_expenses.inject({}){|sum, ie|
				sum.merge({ie.tracker[:name] => 
					ie.issues_scheduled_interval(@projects.map(&:id), @start_date, @end_date).sum{|i| i.amount.to_f}
				})
			}
		end

		def variable_expense_incurred
			@variable_expense_incurred ||= 
			BSC::Integration.get_variable_expenses.inject(0.0){|sum, ie|
				sum += ie.issues_incurred_interval(@projects.map(&:id), @start_date, @end_date).sum{|i| i.amount.to_f}
			}
		end

		def variable_expense_incurred_by_tracker
			@variable_expense_incurred_by_tracker ||= 
			BSC::Integration.get_variable_expenses.inject({}){|sum, ie|
				sum.merge({ie.tracker[:name] => 
					ie.issues_incurred_interval(@projects.map(&:id), @start_date, @end_date).sum{|i| i.amount.to_f}
				})
			}
		end

# Fixed Expense
		def fixed_expense_scheduled
			@fixed_expense_scheduled ||= 
			(result = 0.0
			BSC::Integration.get_fixed_expenses.each do |ie|
				ie.issues_scheduled_interval(@projects.map(&:id), @start_date, @end_date).each do |i|
					start_date = [@start_date, i[:start_date]].max
					end_date = [@end_date, i[:due_date]].min
					amount = i[:amount].to_f	
					result += amount * (end_date - start_date + 1).to_f / (i[:due_date] - i[:start_date] + 1).to_f if start_date <= end_date
				end
			end
			result)
		end

		def fixed_expense_scheduled_by_tracker
			@fixed_expense_scheduled_by_tracker ||= 
			(result = {}
			BSC::Integration.get_fixed_expenses.each do |ie|
				result[ie.tracker[:name]] = 0.0
				ie.issues_scheduled_interval(@projects.map(&:id), @start_date, @end_date).each do |i|
					start_date = [@start_date, i[:start_date]].max
					end_date = [@end_date, i[:due_date]].min
					amount = i[:amount].to_f	
					result[ie.tracker[:name]] += amount * (end_date - start_date + 1).to_f / (i[:due_date] - i[:start_date] + 1).to_f if start_date <= end_date
				end
			end
			result)
		end

		# solo para start_date y end_date de tipo 'attr'
		def fixed_expense_incurred
			@fixed_expense_incurred ||=
			(result = 0.0
			BSC::Integration.get_fixed_expenses.each do |ie|
				ie.issues_incurred_interval(@projects.map(&:id), @start_date, @end_date).each do |i|
					start_date = [@start_date, i[:start_date]].max
					end_date = [@end_date, i[:due_date], Date.today].min
					amount = i[:amount].to_f
					result += amount * (end_date - start_date + 1).to_f / (i[:due_date] - i[:start_date] + 1).to_f if start_date <= end_date
				end
			end
			result)
		end

		def fixed_expense_incurred_by_tracker
			@fixed_expense_incurred_by_tracker ||=
			(result = {}
			BSC::Integration.get_fixed_expenses.each do |ie|
				result[ie.tracker[:name]] = 0.0
				ie.issues_incurred_interval(@projects.map(&:id), @start_date, @end_date).each do |i|
					start_date = [@start_date, i[:start_date]].max
					end_date = [@end_date, i[:due_date], Date.today].min
					amount = i[:amount].to_f	
					result[ie.tracker[:name]] += amount * (end_date - start_date + 1).to_f / (i[:due_date] - i[:start_date] + 1).to_f if start_date <= end_date
				end
			end
			result)
		end
	end
end