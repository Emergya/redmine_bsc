module BscHelper
  def project_bsc_tabs(selected)
    tabs = [
        {:name => 'info', :url => {:controller => :bsc_management, :action => :index}, :label => l(:"bsc.label_info")},
        {:name => 'checkpoints', :url => {:controller => :bsc_checkpoints, :action => :index}, :label => l(:"bsc.label_checkpoints")},
        {:name => 'metrics', :url => {:controller => :bsc_metrics, :action => :index}, :label => l(:"bsc.label_metrics")}
    ]
  end

  def render_project_bsc_tab(selected)
    tabs = project_bsc_tabs(selected).select{|t| User.current.allowed_to?(t[:url], @project)}
    render :partial => 'bsc_management/tabs', :locals => {:tabs => tabs, :selected => selected}
  end
end