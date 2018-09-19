class BscCheckpointEffort < ActiveRecord::Base
  belongs_to :bsc_checkpoint, :inverse_of => :bsc_checkpoint_efforts
  #belongs_to :profile, class_name:'HrProfile'

  validates_presence_of :bsc_checkpoint, :hr_profile_id, :scheduled_effort
  validates_numericality_of :scheduled_effort

  def scheduled_cost
    hourly_cost = BSC::Integration.get_hourly_cost(hr_profile_id, year)
    scheduled_effort * hourly_cost
  end

  # def incurred_effort
  # 	TimeEntry.where('project_id = ? AND spent_on <= ?', bsc_checkpoint.project_id, bsc_checkpoint.checkpoint_date).sum(:hours)
  # end

  # def incurred_cost
  #   TimeEntry.where('project_id = ? AND spent_on <= ?', bsc_checkpoint.project_id, bsc_checkpoint.checkpoint_date).sum(:cost)
  # end

  # def hourly_cost
  # 	BSC::Integration.get_hourly_cost(hr_profile_id, bsc_checkpoint[:checkpoint_date].year)
  # end

  # def scheduled_cost
  #   incurred_cost + ((scheduled_effort - incurred_effort) * hourly_cost)
  # end

  # def get_ideal_capacity(date)
  #   profiles_number = 1
  #   scheduled_effort - TimeEntry.where('project_id IN (?) AND spent_on <= ? AND hr_profile_id = ?', @projects.map(&:id), date, profile)
  # end
end
