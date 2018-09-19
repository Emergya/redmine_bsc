require_dependency 'projects_controller'

module BSC
  module ProjectsControllerPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
      base.class_eval do
      end
    end

    module InstanceMethods
      def setting_bsc_manage_dates
        @project.bsc_manage_dates = params[:bsc_manage_dates]

        if @project.save
          flash[:notice] = l(:notice_successful_update)
        else

        end

        redirect_to settings_project_path(@project, :tab => 'bsc')
      end
    end

    module ClassMethods
    end
  end
end

ActionDispatch::Callbacks.to_prepare do
  ProjectsController.send(:include, BSC::ProjectsControllerPatch)
end
