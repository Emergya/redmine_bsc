module BSC
	class Metrics
		def initialize(project, date = Date.today)
			@hr_plugin = BSC::Integration.hr_plugin_enabled?
			@ie_plugin = BSC::Integration.ie_plugin_enabled?
			@date = date
			# @projects = Array(Project.find(450)) #Array(Project.find([391,450]))
			@projects = Array(Project.find(project).self_and_descendants)
		end

		def hhrr_hours_scheduled
			@hhrr_hours_scheduled ||= 
			(begin
				if @projects.count == 1
					@projects.first.last_checkpoint(@date).bsc_checkpoint_efforts.sum(:scheduled_effort)
				else
					result = 0.0
					@projects.each do |project|
						if (last_checkpoint = project.last_checkpoint(@date)).present?
							result += last_checkpoint.bsc_checkpoint_efforts.sum(:scheduled_effort) 
						end
					end
					result
				end
			rescue
				0.0
			end)
		end

		def hhrr_hours_scheduled_by_profile
			@hhrr_hours_scheduled_by_profile ||= 
			(begin
				if @hr_plugin
					if @projects.count == 1
						@projects.first.last_checkpoint(@date).scheduled_profile_effort_hash
					else
						result = Hash.new(0.0)
						# map_profiles = HrProfile.all.inject({}){|map, profile| map.merge({profile.id => profile.name})}
						@projects.each do |project|
							if (last_checkpoint = project.last_checkpoint(@date)).present?
								last_checkpoint.scheduled_profile_effort_hash.each do |profile_id,hours|
									# result[map_profiles[profile_id]] += hours
									result[profile_id] += hours
								end
							end
						end
						result
					end
				else
					{}
				end
			rescue
				{}
			end)
		end

		def hhrr_cost_scheduled
			@hhrr_cost_scheduled ||= 
			(hourly_cost_by_profile = Hash.new(0.0).merge(BSC::Integration.get_hourly_cost_array(@date.year))
			hours_incurred_by_profile = Hash.new(0.0).merge(hhrr_hours_incurred_by_profile)

			hhrr_hours_scheduled_by_profile.inject(hhrr_cost_incurred){|sum, (profile, effort)|
				sum += (effort - hours_incurred_by_profile[profile]) * hourly_cost_by_profile[profile]
			})
		end

		def hhrr_cost_scheduled_by_profile
			# hhrr_hours_scheduled_by_profile.inject({}){|sum, (profile, effort)|
			# 	sum.merge({profile => })
			# }
		end

		def hhrr_hours_incurred
			@hhrr_hours_incurred ||= TimeEntry.where('project_id IN (?) AND spent_on <= ?', @projects.map(&:id), @date).sum(:hours)
		end

		# Estudiar optimización
		def hhrr_hours_incurred_by_profile
			@hhrr_hours_incurred_by_profile ||=
			(if @hr_plugin
				# TimeEntry.where('project_id IN (?) AND spent_on <= ?', @projects.map(&:id), @date).group_by(&:hr_profile_id).inject({}){|sum, (profile_id, time_entries)|
				# 	sum.merge({profile_id => time_entries.sum(&:hours)})
				# }
				result = Hash.new(0.0)
				TimeEntry.where('project_id IN (?) AND spent_on <= ?', @projects.map(&:id), @date).each do |te|
					# profile_name = te[:hr_profile_id].present? ? te.hr_profile.name : "Undefined"
					# result[profile_name] += te.hours
					result[te.hr_profile_id] += te.hours
				end
				result
			else
				0.0
			end)
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
				# TimeEntry.where('project_id IN (?) AND spent_on <= ?', @projects.map(&:id), @date).group_by(&:hr_profile_id).inject({}){|sum, (profile_id, time_entries)|
				# 	sum.merge({profile_id => time_entries.sum(&:cost)})
				# }
				result = Hash.new(0.0)
				TimeEntry.where('project_id IN (?) AND spent_on <= ?', @projects.map(&:id), @date).each do |te|
					# profile_name = te[:hr_profile_id].present? ? te.hr_profile.name : "Undefined"
					# result[profile_name] += te.cost
					result[te.hr_profile_id] += te.cost
				end
				result
			else
				0.0
			end)
		end

		def variable_income_scheduled
			@variable_income_scheduled ||=
			(if @ie_plugin
				IeVariableIncome.all.inject(0.0){|sum, ie|
					sum += 
						ie.issues_scheduled(@projects.map(&:id), @date).sum{|i| i.amount.to_f} + 
						ie.issues_incurred(@projects.map(&:id), @date).sum{|i| i.amount.to_f}
					# sum += ie.issues_incurred(@projects.map(&:id), @date).sum{|i| i.amount.to_f}
				}
			else
				0.0
			end)
		end

		def variable_income_scheduled_by_tracker
			@variable_income_scheduled_by_tracker ||=
			(if @ie_plugin
				IeVariableIncome.all.inject({}){|sum, ie|
					sum.merge({ie.tracker.name => 
						ie.issues_scheduled(@projects.map(&:id), @date).sum{|i| i.amount.to_f} + 
						ie.issues_incurred(@projects.map(&:id), @date).sum{|i| i.amount.to_f}
					})
					#sum.merge({ie.tracker.name => ie.issues_incurred(@projects.map(&:id), @date).sum{|i| i.amount.to_f}})
				}
			else
				0.0
			end)
		end

		def variable_income_incurred
			@variable_income_incurred ||=
			(if @ie_plugin
				IeVariableIncome.all.inject(0.0){|sum, ie|
					sum += ie.issues_incurred(@projects.map(&:id), @date).sum(:amount)
				}
			else
				0.0
			end)
		end

		def variable_expense_scheduled
			@variable_expense_scheduled ||=
			(if @ie_plugin
				IeVariableExpense.all.inject(0.0){|sum, ie|
					sum += 
						ie.issues_scheduled(@projects.map(&:id), @date).sum{|i| i.amount.to_f} + 
						ie.issues_incurred(@projects.map(&:id), @date).sum{|i| i.amount.to_f}
					# sum += ie.issues_incurred(@projects.map(&:id), @date).sum{|i| i.amount.to_f}
				}
			else
				0.0
			end)
		end

		def variable_expense_scheduled_by_tracker
			@variable_expense_scheduled_by_tracker ||= 
			(if @ie_plugin
				IeVariableExpense.all.inject({}){|sum, ie|
					sum.merge({ie.tracker.name => 
						ie.issues_scheduled(@projects.map(&:id), @date).sum{|i| i.amount.to_f} + 
						ie.issues_incurred(@projects.map(&:id), @date).sum{|i| i.amount.to_f}

					})
					# sum.merge({ie.tracker.name => ie.issues_incurred(@projects.map(&:id), @date).sum{|i| i.amount.to_f}})
				}
			else
				0.0
			end)
		end

		def variable_expense_incurred
			@variable_expense_incurred ||= 
			(if @ie_plugin
				IeVariableExpense.all.inject(0.0){|sum, ie|
					sum += ie.issues_incurred(@projects.map(&:id), @date).sum{|i| i.amount.to_f}
				}
			else
				0.0
			end)
		end

		def fixed_expense_scheduled
			@fixed_expense_scheduled ||=
			(if @ie_plugin
				IeFixedExpense.all.inject(0.0){|sum, ie|
					sum += 
						ie.issues_scheduled(@projects.map(&:id), @date).sum{|i| i.amount.to_f} + 
						ie.issues_incurred(@projects.map(&:id), @date).sum{|i| i.amount.to_f}
					# sum += ie.issues_incurred(@projects.map(&:id), @date).sum{|i| i.amount.to_f}
				}
			else
				0.0
			end)
		end

		def fixed_expense_scheduled_by_tracker
			@fixed_expense_scheduled_by_tracker ||= 
			(if @ie_plugin
				IeFixedExpense.all.inject({}){|sum, ie|
					sum.merge({ie.tracker.name => 
						ie.issues_scheduled(@projects.map(&:id), @date).sum{|i| i.amount.to_f} + 
						ie.issues_incurred(@projects.map(&:id), @date).sum{|i| i.amount.to_f}
					})
					# sum.merge({ie.tracker.name => ie.issues_incurred(@projects.map(&:id), @date).sum{|i| i.amount.to_f}})
				}
			else
				{}
			end)
		end

		# def fixed_expense_incurred
		# 	@fixed_expense_incurred ||= 
		# 	(if @ie_plugin
		# 		IeFixedExpense.all.inject(0.0){|sum, ie|
		# 			sum += ie.issues_scheduled(@projects.map(&:id), @date).sum{|i| i.amount.to_f * ()}
		# 			sum += ie.issues_incurred(@projects.map(&:id), @date).sum{|i| i.amount.to_f}
		# 		}
		# 	else
		# 		0.0
		# 	end)
		# end

		def total_income_scheduled
			@total_income_scheduled ||= variable_income_scheduled
		end

		def total_income_scheduled_by_concept
			@total_income_scheduled_by_concept ||= variable_income_scheduled_by_tracker
		end

		def total_income_incurred
			@total_income_incurred ||= variable_income_incurred
		end

		def total_expense_scheduled
			@total_expense_scheduled ||= hhrr_cost_scheduled + variable_expense_scheduled + fixed_expense_scheduled
		end

		def total_expense_scheduled_by_concept
			@total_expense_scheduled_by_concept ||= [{"RRHH" => hhrr_cost_scheduled}, variable_expense_scheduled_by_tracker, fixed_expense_scheduled_by_tracker].reduce(&:merge)
		end

		def total_expense_incurred
			@total_expense_incurred ||= hhrr_cost_incurred + variable_expense_incurred + fixed_expense_incurred
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
			end)
		end

		def margin_target
			@margin_target ||= 
			(if @projects.count == 1
				@projects.first.last_checkpoint(@date).target_margin
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
			@scheduled_finish_date ||= @projects.map{|p| p.last_checkpoint(@date)}.reject{|c| c.blank?}.map(&:scheduled_finish_date).max
		end

		# def hhrr_ideal_capacity_by_profile
		# 	if @hr_plugin
		# 		scheduled = Hash.new(0.0).merge(hhrr_hours_scheduled_by_profile)
		# 		incurred = Hash.new(0.0).merge(hhrr_hours_incurred_by_profile)

		# 		profiles_number = Hash.new(0)
		# 		@projects.each do |project|
		# 			if (last_checkpoint = project.last_checkpoint(@date)).present?
		# 				last_checkpoint.bsc_checkpoint_efforts.inject({}){|e| {e.hr_profile_id => e.profiles_number} }.each do |profile, number|
		# 					profiles_number[profile] += number
		# 				end
		# 			end
		# 		end

		# 		result = Hash.new(0.0)
		# 		(scheduled.keys + incurred.keys).uniq.each do |profile|
		# 			result = scheduled - incurred
		# 		end



		# 	else
		# 		{}
		# 	end
		# end
	end
end