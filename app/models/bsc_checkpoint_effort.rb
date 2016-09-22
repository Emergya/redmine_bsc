class BscCheckpointEffort < ActiveRecord::Base
  belongs_to :bsc_checkpoint, :inverse_of => :bsc_checkpoint_efforts
  belongs_to :profile, class_name:'HrProfile'

  validates_presence_of :bsc_checkpoint, :hr_profile_id, :scheduled_effort
  validates_numericality_of :scheduled_effort

end
