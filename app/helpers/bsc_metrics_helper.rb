module BscMetricsHelper
	# def summation_by_group(hash, field, field_value = :value)
 #    options = [:date, :type, :subtype]
 #    if options.include?(field)
 #      hash.group_by{|e| e[field]}.map{|k, elements| {k => elements.sum{|e| e[field_value]}}}
 #    else
 #      nil
 #    end
  # end
  def render_mc_header_text(type, mc, mt)
  	type_text = (type == 'alert') ? "<b>#{percent(mt-mc)}</b> puntos por <b>debajo</b>" : "<b>#{percent(mc-mt)}</b> puntos por <b>encima</b>" 
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

  def render_income_expenses_header_text(type, number)
  	case type 
  	when 'alert'
		text = "Hay <b>#{number}</b> pagos o cobros atrasados"
	when 'warn'
		text = "Hay <b>#{number}</b> pagos o cobros pendientes para esta semana"
	else
		text = "<b>No</b> hay pagos o cobros pendientes para esta semana"
	end
	text.html_safe
  end

  def render_deliverable_header_text
  end

  def render_time_entries_header_text
  end
end