class BscProjectInfo < ActiveRecord::Base
	belongs_to :project

	validates :actual_start_date, :date => true #, :allow_nil => true
  validates :scheduled_start_date, :date => true, :presence => true
  validates :scheduled_finish_date, :date => true, :presence => true
  validates_numericality_of :scheduled_qa_meetings, :presence => true, :only_integer => true
end