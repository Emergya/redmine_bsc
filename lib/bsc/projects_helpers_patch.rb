require_dependency 'projects_helper'

# Patches Redmine's ApplicationController dinamically. Redefines methods wich
# send error responses to clients
module BSC
  module ProjectsHelperPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      base.class_eval do
        alias_method_chain :project_settings_tabs, :bsc
      end
    end

    module ClassMethods
    end 

    module InstanceMethods
      def project_settings_tabs_with_bsc
        tabs = project_settings_tabs_without_bsc
        tabs << {:name => 'bsc', :action => :bsc_settings, :partial => 'projects/settings/bsc', :label => :"bsc.label_bsc"}

        tabs.select {|tab| User.current.allowed_to?(tab[:action], @project)}
      end
    end
  end
end


ActionDispatch::Callbacks.to_prepare do
  ProjectsHelper.send(:include, BSC::ProjectsHelperPatch)
end