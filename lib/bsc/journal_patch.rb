module BSC
  module JournalPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      # Same as typing in the class
      base.class_eval do
        scope :visible, lambda {|*args|
          user = args.shift || User.current
          joins(:issue => :project).
            where("#{Journal.table_name}.journalized_type = 'BscCheckpoint' OR "+Issue.visible_condition(user, *args)).
            where("(#{Journal.table_name}.private_notes = ? OR (#{Project.allowed_to_condition(user, :view_private_notes, *args)}))", false)
        }
      end
    end

    module ClassMethods
    end

    module InstanceMethods
    end
  end
end

ActionDispatch::Callbacks.to_prepare do
  Journal.send(:include, BSC::JournalPatch)
end
