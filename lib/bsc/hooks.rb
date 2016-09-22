module BSC
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_journals_update_js_bottom,
              :partial => 'hooks/bsc/view_journals_update_js_bottom'
  end
end