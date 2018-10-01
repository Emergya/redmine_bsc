module BscHelper
  def project_bsc_tabs(selected)
    tabs = [
        {:name => 'info', :url => {:controller => :bsc_management, :action => :index}, :label => l(:"bsc.label_info")},
        {:name => 'checkpoints', :url => {:controller => :bsc_checkpoints, :action => :index}, :label => l(:"bsc.label_checkpoints"), :hide => @project.bsc_info.blank?},
        {:name => 'metrics', :url => {:controller => :bsc_metrics, :action => :index}, :label => l(:"bsc.label_metrics")}
    ]
  end

  def render_project_bsc_tab(selected)
    tabs = project_bsc_tabs(selected).select{|t| User.current.allowed_to?(t[:url], @project)}
    render :partial => 'bsc_management/tabs', :locals => {:tabs => tabs, :selected => selected}
  end

  def currency(n, year = nil)
    if @currency.present?
      exchange = year.present? ? @currency.get_exchange(year) : @currency.get_current_exchange
      value = n.to_f * exchange
      number_to_currency value, :unit => @currency.symbol, :separator => @currency.decimal_separator, :delimiter => @currency.thousands_separator, :precision => 2
    else
      number_to_currency n, :locale => Setting.default_language
    end
  end

  def hours(n)
    t :label_f_hour_plural, :value => (n.round(2) rescue n)
  end

  def percent(n)
    "#{n.round(2) rescue n} %"
  end

  def decimal(n)
    # "#{n.round(2) rescue n}"
    number_with_delimiter(n.round(2), locale: Setting.default_language)
    # number_with_delimiter(n, delimiter: '.', separator: ',')
  end

  def date_es(date)
    date.strftime('%d/%m/%Y')
  end
end