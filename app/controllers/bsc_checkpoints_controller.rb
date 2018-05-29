class BscCheckpointsController < ApplicationController
	before_filter :find_project_by_project_id, :authorize
  before_filter :get_profiles, :only => [:new, :edit, :show]
  before_filter :find_checkpoint, :only => [:show, :edit, :update, :destroy]
  before_filter :has_bsc_project_info
	
  menu_item :bsc
	helper :bsc

  def index
    @limit = per_page_option
    @count = BscCheckpoint.where('project_id = ?', @project).count
    @pages = Paginator.new @count, @limit, params['page']
    @offset ||= @pages.current.offset
    @sort = sort_column
    @order = sort_direction
    @checkpoints = BscCheckpoint.where(project_id: @project).
                                    	order([@sort, @order].join(' ')).
                                     	offset(@offset).
                                     	limit(@limit).
                                     	includes(:bsc_checkpoint_efforts)       	
  end

  def new
    @checkpoint = BscCheckpoint.new @project

    if @project.first_checkpoint.blank?
      @first_checkpoint = true
      @checkpoint.base_line = true
      @checkpoint.scheduled_finish_date = @project.bsc_info.scheduled_finish_date
    end
    
    @profiles.each do |profile|
      @checkpoint.bsc_checkpoint_efforts.build :hr_profile_id => profile.id
    end

    @last_checkpoint = @project.last_checkpoint
  end

  def create
    @checkpoint = BscCheckpoint.new checkpoint_params
    @checkpoint.project = @project
    @checkpoint.author = User.current
    if @checkpoint.save
      flash[:notice] = l(:notice_successful_update)
      redirect_to :action => :index
    else
      get_profiles
      render :action => 'new'
    end
  end

  def show
    @journals = @checkpoint.journals.includes(:user, :details).order("#{Journal.table_name}.created_on ASC")
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals = @journals.reverse if User.current.wants_comments_in_reverse_order?
  end

  def edit
    @journal = @checkpoint.current_journal
    @first_checkpoint = (@project.first_checkpoint == @checkpoint)
    @last_checkpoint = BscCheckpoint.where("project_id = ? AND checkpoint_date < ?", @project.id, @checkpoint.checkpoint_date).order("checkpoint_date DESC").first
  end

  def update
    @checkpoint.init_journal(User.current, params[:notes])
    @checkpoint.attributes = checkpoint_params #params[:checkpoint]

    if @checkpoint.save
      flash[:notice] = l(:notice_successful_update)
      redirect_back_or_default({:action => 'show', :id => @checkpoint})
    else
      get_profiles
      @journal = @checkpoint.current_journal
      render :action => 'edit'
    end
  end

  def destroy
    @checkpoint.destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_back_or_default(:action => 'index', :project_id => @project)
  end

  private

  def find_checkpoint
    @checkpoint = BscCheckpoint.includes(:bsc_checkpoint_efforts).find(params[:id])
    unless @checkpoint.project_id == @project.id
      deny_access
      return
    end
  end

  def sort_column
    BscCheckpoint.column_names.include?(params[:sort]) ? params[:sort] : "checkpoint_date"
  end

  def sort_direction
    %w[asc desc].include?(params[:order]) ? params[:order] : "desc"
  end

  def get_profiles
    @profiles = BSC::Integration.get_profiles
  end

  def checkpoint_params
    params.require(:checkpoint).permit(:project_id, :author_id, :description, :checkpoint_date, :scheduled_finish_date, :held_qa_meetings, :base_line, :target_expenses, :target_incomes, :achievement_percentage, bsc_checkpoint_efforts_attributes: [:id, :hr_profile_id, :scheduled_effort, :number, :year])
  end

  def has_bsc_project_info
    unless @project.bsc_info.present?
      deny_access
      return
    end
  end
end
