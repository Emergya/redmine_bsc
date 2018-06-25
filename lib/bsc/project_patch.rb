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

      def real_last_checkpoint
        begin
          bsc_checkpoints.order('checkpoint_date DESC').first
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
          if last_checkpoint
            last_checkpoint.scheduled_finish_date
          else
            bsc_info.scheduled_finish_date
          end
        rescue
         nil
        end
      end

      def real_start_date
        begin
          [issues.minimum(:created_on), time_entries.minimum(:created_on)].min
        rescue
          nil
        end
      end

      def real_end_date
        begin
          [issues.maximum(:created_on), time_entries.maximum(:created_on)].max
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
