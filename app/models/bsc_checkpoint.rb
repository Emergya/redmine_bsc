class BscCheckpoint < ActiveRecord::Base
  belongs_to :project
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  has_many :bsc_checkpoint_efforts, :dependent => :destroy, :inverse_of => :bsc_checkpoint
  has_many :journals, :as => :journalized, :dependent => :destroy
  acts_as_customizable

  accepts_nested_attributes_for :bsc_checkpoint_efforts, :allow_destroy => true

  validates_presence_of :project, :author
  validates_format_of :checkpoint_date, :with => /\d{4}-\d{2}-\d{2}/, :message => :not_a_date, :allow_nil => false
  validates_format_of :scheduled_finish_date, :with => /\d{4}-\d{2}-\d{2}/, :message => :not_a_date, :allow_nil => false
  validates_numericality_of :held_qa_meetings, :only_integer => true
  validates_numericality_of :target_expenses, :allow_nil => false
  validates_numericality_of :target_incomes, :allow_nil => false

  attr_protected :project_id, :author_id
  attr_reader :current_journal
  after_save :create_journal, :set_first_base_line
  after_destroy :set_first_base_line

  def initialize(copy_from_project=nil)
    if copy_from_project.is_a? Project
      previous = BscCheckpoint.where('project_id = ?', copy_from_project).
                              order('checkpoint_date DESC, created_at DESC').
                              first
      super((previous.nil? ? {} : previous.attributes).merge(:checkpoint_date => Date.today, :base_line => false, :title => nil))

      if previous.present?
        # Copy previous checkpoint efforts
        efforts = previous.bsc_checkpoint_efforts
        efforts.each do |eff|
          eff.id = nil
          eff.created_at = Date.today
          eff.updated_at = Date.today
        end
        self.bsc_checkpoint_efforts = efforts
      end
    else
      super
    end
  end

  def init_journal(user, notes = "")
    @current_journal ||= Journal.new(:journalized => self, :user => user, :notes => notes)
  end

  # Returns the names of attributes that are journalized when updating the issue
  def journalized_attribute_names
    BscCheckpoint.column_names - %w(id created_at updated_at)
  end

  # Method needed to show checkpoint journals
  def notified_users
    []
  end

  # Method needed to show checkpoint journals
  def notified_watchers
    []
  end

  # Method needed to show checkpoint journals
  def attachments
    []
  end

  def scheduled_profile_number(profile_id)
    efforts = bsc_checkpoint_efforts.select{ |effort| effort.hr_profile_id == profile_id }
    efforts.present? ? Hash.new(0.0).merge(efforts.map{|e| {e.year => e.number}}.reduce(:merge)) : Hash.new(0.0)
  end

  def scheduled_profile_number_year(year)
    efforts = bsc_checkpoint_efforts.select{ |effort| effort.year == year }
    efforts.present? ? Hash.new(0.0).merge(efforts.map{|e| {e.hr_profile_id => e.number}}.reduce(:merge)) : Hash.new(0.0)
  end

  def scheduled_profile_effort(profile_id)
    efforts = bsc_checkpoint_efforts.select{ |effort| effort.hr_profile_id == profile_id }
    efforts.present? ? Hash.new(0.0).merge(efforts.map{|e| {e.year => e.scheduled_effort}}.reduce(:merge)) : Hash.new(0.0)
  end

  def scheduled_profile_effort_cost(profile_id)
    efforts = bsc_checkpoint_efforts.select{ |effort| effort.hr_profile_id == profile_id }
    efforts.present? ? Hash.new(0.0).merge(efforts.map{|e| {e.year => e.scheduled_cost}}.reduce(:merge)) : Hash.new(0.0)
  end

  def scheduled_profile_effort_year(year)
    efforts = bsc_checkpoint_efforts.select{ |effort| effort.year == year }
    efforts.present? ? Hash.new(0.0).merge(efforts.map{|e| {e.hr_profile_id => e.scheduled_effort}}.reduce(:merge)) : Hash.new(0.0)
  end

  def scheduled_profile_effort_year_cost(year)
    efforts = bsc_checkpoint_efforts.select{ |effort| effort.year == year }
    efforts.present? ? Hash.new(0.0).merge(efforts.map{|e| {e.hr_profile_id => e.scheduled_cost}}.reduce(:merge)) : Hash.new(0.0)
  end

  def scheduled_profile_effort_id(profile_id)
    efforts = bsc_checkpoint_efforts.select{ |effort| effort.hr_profile_id == profile_id }
    efforts.present? ? efforts.map{|e| {e.year => e.id}}.reduce(:merge) : Hash.new(nil)
  end

  def scheduled_profile_effort_hash
    bsc_checkpoint_efforts.reduce(Hash.new(0.0)) do |hash, effort|
      hash.merge! effort.hr_profile_id => hash[effort.hr_profile_id]+effort.scheduled_effort
    end
  end

  def scheduled_effort
    bsc_checkpoint_efforts.sum(:scheduled_effort)
  end

  def scheduled_effort_cost
    bsc_checkpoint_efforts.reduce(0.0){|sum, e| sum + e.scheduled_cost}
  end

  private

  # Saves the changes in a Journal
  # Called after_save
  def create_journal
    if @current_journal
      profiles = BSC::Integration.get_profiles
      # attributes changes
      # self.changes.each do |c, value|
      #   @current_journal.details << JournalDetail.new(:property => 'attr',
      #                                                 :prop_key => c,
      #                                                 :old_value => value[0],
      #                                                 :value => value[1])
      # end

      # scheduled profile effort
      unless scheduled_profile_effort_hash == @scheduled_profile_effort_hash_before_change
        @current_journal.details << JournalDetail.new(:property => 'attr',
                                                      :prop_key => 'scheduled_effort',
                                                      :old_value => @scheduled_profile_effort_hash_before_change.present? ? @scheduled_profile_effort_hash_before_change.transform_keys{|key| profiles.find{|p| p.id == key }.name } : nil,
                                                      :value => scheduled_profile_effort_hash.present? ? scheduled_profile_effort_hash.transform_keys{|key| profiles.find{|p| p.id == key }.name } : nil)
      end
      # custom fields changes
      @current_journal.save
      # reset current journal
      init_journal @current_journal.user, @current_journal.notes
    end
  end

  # Update oldest checkpoint as base line
  # Called after_save and after_destroy
  def set_first_base_line
    first_checkpoint = project.first_checkpoint
    
    if first_checkpoint.present? and !first_checkpoint.base_line
      first_checkpoint.base_line = true
      first_checkpoint.save
    end
  end
end
