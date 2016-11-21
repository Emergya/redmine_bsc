module BscMetricsHelper
	# def summation_by_group(hash, field, field_value = :value)
 #    options = [:date, :type, :subtype]
 #    if options.include?(field)
 #      hash.group_by{|e| e[field]}.map{|k, elements| {k => elements.sum{|e| e[field_value]}}}
 #    else
 #      nil
 #    end
  # end
  def render_mc_header_text(status, mc, mt)
  	type_text = (mt > mc) ? "<b>#{percent(mt-mc)}</b> puntos por <b>debajo</b>" : "<b>#{percent(mc-mt)}</b> puntos por <b>encima</b>" 
  	text = "El margen previsto actual es de <b>#{percent(mc)}</b>, que está #{type_text} del objetivo"
  	text.html_safe
  end

  def render_effort_header_text(number)
  	if number > 0
  		text = "Hay <b>#{number}</b> perfiles que, con la estimación actual, <b>no</b> podrán completar su dedicación"
  	else
  		text = "Con la estimación actual, todos los perfiles deberían poder completar su dedicación"
  	end
  	text.html_safe
  end

  def render_income_expenses_header_text(status, number)
  	case status 
  	when 'metric_alert'
  		text = "Hay <b>#{number}</b> pagos o cobros atrasados"
  	when 'metric_warning'
  		text = "Hay <b>#{number}</b> pagos o cobros pendientes para esta semana"
  	else
  		text = "<b>No</b> hay pagos o cobros pendientes para esta semana"
  	end
  	text.html_safe
  end

  def render_deliverables_header_text(status, number)
    case status 
    when 'metric_alert'
      text = "Hay <b>#{number}</b> entregables atrasados"
    when 'metric_warning'
      text = "Hay <b>#{number}</b> entregables pendientes para esta semana"
    else
      text = "<b>No</b> hay entregables pendientes para esta semana"
    end
    text.html_safe
  end

  def render_time_entries_header_text(status, number)
    case status
    when 'metric_alert'
      text = "Hay <b>#{number}</b> usuarios que han participado en el proyecto y no cargan horas desde hace más de <b>14 días</b>"
    when 'metric_warning'
      text = "Hay <b>#{number}</b> usuarios que han participado en el proyecto y no cargan horas desde hace más de <b>7 días</b>"
    else
      text = "Todos los usuarios que han participado en el proyecto realizan regularmente las imputaciones"
    end
    text.html_safe
  end

  def render_link_show_more(table_name)
    link_to(l(:'bsc.label_show_more'), '#'+table_name, {:class => 'show_hide_rows', :data => {:table => table_name} })
  end

  def render_mc_table_cell(details, tracker)
     value = details.keys.include?(tracker[:name]) ? currency(details[tracker[:name]]) : currency(0.0)
  end

  def render_tracker_query_link(tracker)
    ie = tracker.ie_income_expenses.first

    amount_field = 'cf_'+ie[:amount_field_id].to_s
    start_field = (ie[:start_field_type] == 'cf') ? 'cf_'+ie[:start_date_field].to_s : ie[:start_date_field]
    planned_end_field = (ie[:planned_end_field_type] == 'cf') ? 'cf_'+ie[:planned_end_date_field].to_s : ie[:planned_end_date_field]
  
    if ie.is_a?(IeFixedExpense)
      columns = ['tracker', 'status', 'subject', start_field, planned_end_field, amount_field, 'updated_on', 'project']
    else
      columns = ['tracker', 'status', 'subject', start_field, planned_end_field, amount_field, 'assigned_to', 'updated_on', 'project']
    end

    link_to(tracker[:name], project_issues_path(@project, 
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
    link_to(l(:"label_report"), report_project_time_entries_path(@project,
      { 
        :criteria => ['user', 'profile'],
        :f => ['spent_on'],
        :op => {'spent_on' => '*'},
        :columns => ['month']
      }
    ))
  end
end