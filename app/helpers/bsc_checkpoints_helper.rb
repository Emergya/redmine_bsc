module BscCheckpointsHelper
	# Returns a link which sorts by the named column.
  #
  # - column is the name of an attribute in the sorted record collection.
  # - the optional caption explicitly specifies the displayed link text.
  # - 2 CSS classes reflect the state of the link: sort and asc or desc
  #
  def sort_link(column, caption, default_order)
    css, order = nil, default_order

    if @sort == column
      if @order == 'asc'
        css = 'sort asc'
        order = 'desc'
      else
        css = 'sort desc'
        order = 'asc'
      end
    end
    caption = column.to_s.humanize unless caption

    sort_options = { :sort => column.to_s, :order => order }
    url_options = params.merge(sort_options)

    # Add project_id to url_options
    url_options = url_options.merge(:project_id => params[:project_id]) if params.has_key?(:project_id)

    link_to_content_update(caption, url_options, :class => css)
  end

  # Returns a table header <th> tag with a sort link for the named column
  # attribute.
  #
  # Options:
  #   :caption     The displayed link name (defaults to titleized column name).
  #   :title       The tag's 'title' attribute (defaults to 'Sort by :caption').
  #
  # Other options hash entries generate additional table header tag attributes.
  #
  # Example:
  #
  #   <%= sort_header_tag('id', :title => 'Sort by contact ID', :width => 40) %>
  #
  def sort_header_tag(column, options = {})
    caption = options.delete(:caption) || column.to_s.humanize
    default_order = options.delete(:default_order) || 'asc'
    options[:title] = l(:label_sort_by, "\"#{caption}\"") unless options[:title]
    content_tag('th', sort_link(column, caption, default_order), options)
  end

  def render_notes(model, journal, options={})
    content = ''
    editable = User.current.logged? && (User.current.allowed_to?(:edit_issue_notes, model.project) || (journal.user == User.current && User.current.allowed_to?(:edit_own_issue_notes, model.project)))
    links = []
    if !journal.notes.blank?
      links << link_to_in_place_notes_editor(image_tag('edit.png'), "journal-#{journal.id}-notes", 
      																					{ :controller => 'journals', :action => 'edit', :id => journal, :format => 'js' },
                                                :title => l(:button_edit)) if editable
    end
    content << content_tag('div', links.join(' ').html_safe, :class => 'contextual') unless links.empty?
    content << textilizable(journal, :notes)
    css_classes = "wiki"
    css_classes << " editable" if editable
    content_tag('div', content.html_safe, :id => "journal-#{journal.id}-notes", :class => css_classes).html_safe
  end

  # (copied from journals_helper)
  def link_to_in_place_notes_editor(text, field_id, url, options={})
    onclick = "$.ajax({url: '#{url_for(url)}', type: 'get'}); return false;"
    link_to text, '#', options.merge(:onclick => onclick)
  end

  # Show differences in notes
  # Returns the textual representation of a single journal detail (copied from issues_helper)
  def show_detail(detail, no_html=false, options={})
    multiple = false
    show_diff = false

    case detail.property
    when 'attr'
      field = detail.prop_key.to_s.gsub(/\_id$/, "")
      label = l(("field_" + field).to_sym)
      case detail.prop_key
      when 'scheduled_profile_effort'
        profiles = Hash.new('Unknwon').merge(HrProfile.all.map{|p| [p.id, p.name]}.to_h)
        detail.value = eval(detail.value).map{|k, v| [profiles[k], v] }.to_h
      when 'due_date', 'start_date'
        value = format_date(detail.value.to_date) if detail.value
        old_value = format_date(detail.old_value.to_date) if detail.old_value

      when 'project_id', 'status_id', 'tracker_id', 'assigned_to_id',
            'priority_id', 'category_id', 'fixed_version_id'
        value = find_name_by_reflection(field, detail.value)
        old_value = find_name_by_reflection(field, detail.old_value)

      when 'estimated_hours'
        value = "%0.02f" % detail.value.to_f unless detail.value.blank?
        old_value = "%0.02f" % detail.old_value.to_f unless detail.old_value.blank?

      when 'parent_id'
        label = l(:field_parent_issue)
        value = "##{detail.value}" unless detail.value.blank?
        old_value = "##{detail.old_value}" unless detail.old_value.blank?

      when 'is_private'
        value = l(detail.value == "0" ? :general_text_No : :general_text_Yes) unless detail.value.blank?
        old_value = l(detail.old_value == "0" ? :general_text_No : :general_text_Yes) unless detail.old_value.blank?

      when 'description'
        show_diff = true
      end
    when 'cf'
      custom_field = detail.custom_field
      if custom_field
        label = custom_field.name
        if custom_field.format.class.change_as_diff
          show_diff = true
        else
          multiple = custom_field.multiple?
          value = format_value(detail.value, custom_field) if detail.value
          old_value = format_value(detail.old_value, custom_field) if detail.old_value
        end
      end
    when 'attachment'
      label = l(:label_attachment)
    when 'relation'
      if detail.value && !detail.old_value
        rel_issue = Issue.visible.find_by_id(detail.value)
        value = rel_issue.nil? ? "#{l(:label_issue)} ##{detail.value}" :
                  (no_html ? rel_issue : link_to_issue(rel_issue, :only_path => options[:only_path]))
      elsif detail.old_value && !detail.value
        rel_issue = Issue.visible.find_by_id(detail.old_value)
        old_value = rel_issue.nil? ? "#{l(:label_issue)} ##{detail.old_value}" :
                          (no_html ? rel_issue : link_to_issue(rel_issue, :only_path => options[:only_path]))
      end
      relation_type = IssueRelation::TYPES[detail.prop_key]
      label = l(relation_type[:name]) if relation_type
    end
    call_hook(:helper_issues_show_detail_after_setting,
              {:detail => detail, :label => label, :value => value, :old_value => old_value })

    label ||= detail.prop_key
    value ||= detail.value
    old_value ||= detail.old_value

    unless no_html
      label = content_tag('strong', label)
      old_value = content_tag("i", h(old_value)) if detail.old_value
      if detail.old_value && detail.value.blank? && detail.property != 'relation'
        old_value = content_tag("del", old_value)
      end
      if detail.property == 'attachment' && value.present? &&
          atta = detail.journal.journalized.attachments.detect {|a| a.id == detail.prop_key.to_i}
        # Link to the attachment if it has not been removed
        value = link_to_attachment(atta, :download => true, :only_path => options[:only_path])
        if options[:only_path] != false && atta.is_text?
          value += link_to(
                       image_tag('magnifier.png'),
                       :controller => 'attachments', :action => 'show',
                       :id => atta, :filename => atta.filename
                     )
        end
      else
        value = content_tag("i", h(value)) if value
      end
    end

    if show_diff
      s = l(:text_journal_changed_no_detail, :label => label)
      unless no_html
        diff_link = link_to 'diff',
          {:controller => 'journals', :action => 'diff', :id => detail.journal_id,
           :detail_id => detail.id, :only_path => options[:only_path]},
          :title => l(:label_view_diff)
        s << " (#{ diff_link })"
      end
      s.html_safe
    elsif detail.value.present?
      case detail.property
      when 'attr', 'cf'
        if detail.old_value.present?
          l(:text_journal_changed, :label => label, :old => old_value, :new => value).html_safe
        elsif multiple
          l(:text_journal_added, :label => label, :value => value).html_safe
        else
          l(:text_journal_set_to, :label => label, :value => value).html_safe
        end
      when 'attachment', 'relation'
        l(:text_journal_added, :label => label, :value => value).html_safe
      end
    else
      l(:text_journal_deleted, :label => label, :old => old_value).html_safe
    end
  end

  def render_checkpoint_effort_info(effort, number)
    (number > 0) ? 
      effort.to_s+" ("+number.to_s+" perfiles)" :
      effort
  end

end