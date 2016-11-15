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

      def last_checkpoint(date = Date.today)
        begin
          bsc_checkpoints.where('checkpoint_date <= ?', date).order('checkpoint_date DESC').first
        rescue
          nil
        end
      end

      def bsc_start_date
        begin
          bsc_info.scheduled_start_date
        rescue
         nil
        end
      end

      def bsc_end_date
        begin
          last_checkpoint.scheduled_finish_date
        rescue
         nil
        end
      end
    end
  end
end

ActionDispatch::Callbacks.to_prepare do
  Project.send(:include, BSC::ProjectPatch)
end
