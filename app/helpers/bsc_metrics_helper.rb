module BscMetricsHelper
  def render_header_message(metric)
    case metric
    when 'mc'
      data = @mc_header
      text = render_mc_header_text(data[:status], data[:mc], data[:mt], data[:cc], data[:ct])
    when 'effort'
      data = @effort_header
      text = render_effort_header_text(data[:status], data[:result])
    when 'income_expenses'
      data = @income_expenses_header
      text = render_income_expenses_header_text(data[:status], data[:number])
    when 'deliverables'
      data = @deliverables_header
      text = render_deliverables_header_text(data[:status], data[:number])
    when 'time_entries'
      data = @time_entries_header
      text = render_time_entries_header_text(data[:status], data[:number])
    when 'balance'
      data = @balance_header
      text = render_balance_header_text(data[:status], data[:result])
    end

    ['metric_alert', 'metric_warning'].include?(data[:status]) ? ("<div class='status_message "+data[:status]+"'><span>"+text+"</span></div>").html_safe : ''
  end


  def render_mc_header_text_reduced(status, mc, mt, cc, ct)
    alert_margin = (mt > mc)
    alert_expenses = (cc > ct)
    margin_text = alert_margin ? I18n.t('bsc.label_mc_header_bad_margin', points: decimal(mt-mc)) : I18n.t('bsc.label_mc_header_good_margin', points: decimal(mc-mt)) 
    expenses_text = alert_expenses ? I18n.t('bsc.label_mc_header_higher_expenses', amount: currency(cc-ct)) : I18n.t('bsc.label_mc_header_lower_expenses', amount: currency(ct-cc))

    if status == 'metric_success' or (alert_margin and alert_expenses)
      text = I18n.t('bsc.label_mc_reduced_header_metric_success', margin_text: margin_text, expenses_text: expenses_text)
    elsif alert_expenses
      text = I18n.t('bsc.label_mc_reduced_header_metric_expenses_alert', expenses_text: expenses_text)
    else
      text = I18n.t('bsc.label_mc_reduced_header_metric_margin_alert', margin_text: margin_text)
    end

    text.html_safe
  end

  def render_effort_header_text_reduced(status, number)
    if number > 0
      text = I18n.t('bsc.label_effort_reduced_header_alert', number: number)
    else
      text = I18n.t('bsc.label_effort_reduced_header_success')
    end
    text.html_safe
  end

  def render_income_expenses_header_text_reduced(status, number)
    case status 
    when 'metric_alert'
      text = I18n.t('bsc.label_income_expenses_header_alert', number: number)
    when 'metric_warning'
      text = I18n.t('bsc.label_income_expenses_header_warning', number: number)
    else
      text = I18n.t('bsc.label_income_expenses_header_success')
    end
    text.html_safe
  end

  def render_deliverables_header_text_reduced(status, number)
    case status 
    when 'metric_alert'
      text = I18n.t('bsc.label_deliverables_header_alert', number: number)
    when 'metric_warning'
      text = I18n.t('bsc.label_deliverables_header_warning', number: number)
    else
      text = I18n.t('bsc.label_deliverables_header_success')
    end
    text.html_safe
  end

  def render_time_entries_header_text_reduced(status, number)
    case status
    when 'metric_alert'
      text = I18n.t('bsc.label_time_entries_header_alert', number: number)
    when 'metric_warning'
      text = I18n.t('bsc.label_time_entries_header_warning', number: number)
    else
      text = I18n.t('bsc.label_time_entries_header_success')
    end
    text.html_safe
  end

  def render_balance_header_text_reduced(status, number)
    text = I18n.t('bsc.label_balance_header', amount: currency(number))
    text.html_safe
  end



  def render_mc_header_text(status, mc, mt, cc, ct)
    alert_margin = (mt > mc)
    alert_expenses = (cc > ct)
    margin_text = alert_margin ? I18n.t('bsc.label_mc_header_bad_margin', points: decimal(mt-mc)) : I18n.t('bsc.label_mc_header_good_margin', points: decimal(mc-mt)) 
    expenses_text = alert_expenses ? I18n.t('bsc.label_mc_header_higher_expenses', amount: currency(cc-ct)) : I18n.t('bsc.label_mc_header_lower_expenses', amount: currency(ct-cc))

    if alert_margin and alert_expenses
      text = I18n.t('bsc.label_mc_header_metric_both_alert', margin_text: margin_text, expenses_text: expenses_text)
    elsif alert_expenses
      text = I18n.t('bsc.label_mc_header_metric_expenses_alert', amount: currency(cc), expenses_text: expenses_text)
    else
      text = I18n.t('bsc.label_mc_header_metric_margin_alert', percentage: percent(mc), margin_text: margin_text)
    end
  	
  	text.html_safe
  end

  def render_effort_header_text(status, number)
  	if number > 0
  		text = I18n.t('bsc.label_effort_header_alert', number: number)
  	else
  		text = I18n.t('bsc.label_effort_header_success')
  	end
  	text.html_safe
  end

  def render_income_expenses_header_text(status, number)
  	case status 
  	when 'metric_alert'
  		text = I18n.t('bsc.label_income_expenses_header_alert', number: number)
  	when 'metric_warning'
  		text = I18n.t('bsc.label_income_expenses_header_warning', number: number)
  	else
  		text = I18n.t('bsc.label_income_expenses_header_success')
  	end
  	text.html_safe
  end

  def render_deliverables_header_text(status, number)
    case status 
    when 'metric_alert'
      text = I18n.t('bsc.label_deliverables_header_alert', number: number)
    when 'metric_warning'
      text = I18n.t('bsc.label_deliverables_header_warning', number: number)
    else
      text = I18n.t('bsc.label_deliverables_header_success')
    end
    text.html_safe
  end

  def render_time_entries_header_text(status, number)
    case status
    when 'metric_alert'
      text = I18n.t('bsc.label_time_entries_header_alert', number: number)
    when 'metric_warning'
      text = I18n.t('bsc.label_time_entries_header_warning', number: number)
    else
      text = I18n.t('bsc.label_time_entries_header_success')
    end
    text.html_safe
  end

  def render_balance_header_text(status, number)
    text = I18n.t('bsc.label_balance_header', amount: currency(number))
    text.html_safe
  end


  def render_link_show_more(table_name)
    ("<div class='show_more_rows'>"+
    link_to('', '#'+table_name, {:class => 'show_hide_rows show_more', :data => {:table => table_name}, :alt => l(:'bsc.label_show_more')})+
    "</div>").html_safe
  end

  def render_mc_table_cell(details, tracker)
     value = details.keys.include?(tracker[:name]) ? currency(details[tracker[:name]]) : currency(0.0)
  end

  def render_tracker_query_link(tracker)
    ie = tracker.ie_income_expense

    amount_field = 'cf_'+ie[:amount_field_id].to_s
    start_field = (ie[:start_field_type] == 'cf') ? 'cf_'+ie[:start_date_field].to_s : ie[:start_date_field]
    planned_end_field = (ie[:planned_end_field_type] == 'cf') ? 'cf_'+ie[:planned_end_date_field].to_s : ie[:planned_end_date_field]
  
    if ie.is_a?(IeFixedExpense)
      columns = ['tracker', 'status', 'subject', start_field, planned_end_field, amount_field, 'updated_on', 'project']
    else
      columns = ['tracker', 'status', 'subject', start_field, planned_end_field, amount_field, 'assigned_to', 'updated_on', 'project']
    end

    link_to(tracker.name, project_issues_path(@project, 
      { :set_filter => 1, 
        :f => ['tracker_id'], #'created_on'], 
        :op => {'tracker_id' => '='}, #'created_on' => '<='}, 
        :v => {'tracker_id' => [tracker[:id]]}, #'created_on' => [date]}, 
        :c => columns, 
        :t => [amount_field] 
      }
    ))
  end

  def render_time_entries_report_link
    if @project.module_enabled?('time_tracking')
      link_to(l(:"label_report"), report_project_time_entries_path(@project,
        { 
          :criteria => ['user', 'profile'],
          :f => ['spent_on'],
          :op => {'spent_on' => '*'},
          :columns => ['month']
        }
      ))
    else
      nil
    end
  end

  def income_expense_table_row_status(date)
    if Date.parse(date) < Date.today
      return 'alert'
    elsif Date.parse(date) < (Date.today + BscIncomeExpense::DAYS_WARNING)
      return 'warn'
    else
      return ''
    end
  end

  def deliverable_table_row_status(date)
    if Date.parse(date) < Date.today
      return 'alert'
    elsif Date.parse(date) < (Date.today + BscDeliverable::DAYS_WARNING)
      return 'warn'
    else
      return ''
    end
  end

  def time_entry_table_row_status(days)
    if days > BscTimeEntry::MAX_DAYS_ALERT
      return 'alert'
    elsif days > BscTimeEntry::MAX_DAYS_WARNING
      return 'warn'
    else
      return ''
    end
  end

  def render_date_selector
    options = [[l(:"bsc.label_all_project"), '0']]

    (@metrics.real_start_date.year..@metrics.real_finish_date.year).each do |year|
      options << [year, year.to_s]
    end

    selected_date = (params.present? and params[:selected_date].present?) ? params[:selected_date] : nil
    
    render :partial => 'bsc_metrics/metrics/elements/date_selector', :locals => {:options => options, :selected_date => selected_date}
  end
end
