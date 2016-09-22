module BSC
  module PreviewsControllerPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      # Same as typing in the class
      base.class_eval do
        
      end
    end

    module ClassMethods
    end

    module InstanceMethods
      def checkpoint
        find_checkpoint unless params[:id].blank?
        if @checkpoint
          @description = params[:checkpoint] && params[:checkpoint][:description]
          if @description && @description.gsub(/(\r?\n|\n\r?)/, "\n") == @checkpoint.description.to_s.gsub(/(\r?\n|\n\r?)/, "\n")
            @description = nil
          end
          @notes = params[:notes]
        else
          @description = (params[:checkpoint] ? params[:checkpoint][:description] : nil)
        end
        render :layout => false
      end

      private def find_checkpoint
        @checkpoint = BscCheckpoint.includes(:bsc_checkpoint_efforts).find(params[:id])
        unless @checkpoint.project_id == @project.id
          deny_access
          return
        end
      end
    end
  end
end

ActionDispatch::Callbacks.to_prepare do
  require_dependency 'previews_controller'
  PreviewsController.send(:include, BSC::PreviewsControllerPatch)
end
