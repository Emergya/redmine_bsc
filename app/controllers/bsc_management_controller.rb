class BscManagementController < ApplicationController
	before_filter :find_project_by_project_id, :authorize

	menu_item :bsc
	helper :bsc

	def index
	    @bsc_project_info = BscProjectInfo.find_or_create_by(project_id: @project.id)
	    @has_checkpoints = BscCheckpoint.exists?(project_id: @project.id)
	    if request.put? || request.post? || request.patch?
	      @bsc_project_info.attributes = project_info_params
	      flash[:notice] = l(:notice_successful_update) if @bsc_project_info.save
	    end
	end

	def destroy
		@bsc_project_info = BscProjectInfo.find_by(project_id: @project.id)
		if request.delete?
			flash[:notice] = l(:notice_successful_delete) if @bsc_project_info.destroy
	    end
	    redirect_back_or_default(:action => 'index', :project_id => @project)
	end

	private
	def project_info_params
		if !User.current.allowed_to?(:bsc_manage_dates, @project) and @project.bsc_manage_dates
			# params.require(:bsc_project_info).permit(:scheduled_start_date, :scheduled_qa_meetings, :project_id)
		    params[:scheduled_finish_date] = (@project.bsc_info.present? and @project.bsc_info.scheduled_finish_date.present?) ? @project.bsc_info.scheduled_finish_date : ''
		    params[:actual_start_date] = (@project.bsc_info.present? and @project.bsc_info.actual_start_date.present?) ? @project.bsc_info.actual_start_date : ''
		end
		params.require(:bsc_project_info).permit(:actual_start_date, :scheduled_start_date, :scheduled_finish_date, :scheduled_qa_meetings, :project_id)
	end
end