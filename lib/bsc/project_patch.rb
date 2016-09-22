#require_dependency 'project'

module BSC
  module ProjectPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      base.class_eval do
        has_one :bsc_info, :class_name => 'BscProjectInfo', :dependent => :destroy
        has_many :bsc_checkpoints, :dependent => :destroy
      end
    end

    module ClassMethods
    end

    module InstanceMethods
      def first_checkpoint
        bsc_checkpoints.order('checkpoint_date ASC').first
      end
    end
  end
end

ActionDispatch::Callbacks.to_prepare do
  Project.send(:include, BSC::ProjectPatch)
end

