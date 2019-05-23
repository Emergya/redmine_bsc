require 'bsc/project_patch'
require 'bsc/journal_patch'
require 'bsc/previews_controller_patch'
require 'bsc/settings_controller_patch'
require 'bsc/hooks'
require 'bsc/integration'
require 'bsc/projects_controller_patch'
require 'bsc/projects_helpers_patch'

Redmine::Plugin.register :redmine_bsc do
  Rails.configuration.after_initialize do
    locale = if Setting.table_exists?
               Setting.default_language
             else
               'en'
             end
    I18n.with_locale(locale) do
      name I18n.t :'bsc.plugin_name'
      description I18n.t :'bsc.plugin_description'
      author 'Emergya Consultoría'
      version '0.0.1'
    end
  end

  settings :default => {}, :partial => 'settings/bsc_settings'

  project_module :bscplugin do
    permission :bsc_management, { :bsc_management => [:index, :destroy] }
    permission :bsc_checkpoints, { :bsc_checkpoints => [:index, :new, :new_without_annualization, :show, :edit, :destroy, :update, :create, :create_without_annualization] }
    permission :bsc_metrics, { :bsc_metrics => [:index, :change_metric] }
    permission :bsc_manage_dates, {:bsc_checkpoints => [:create, :create_without_annualization, :update], :bsc_management => [:index]}
    permission :bsc_settings, {:projects => [:settings]}
  end

  menu :project_menu, :bsc, { :controller => 'bsc_management', :action => 'index' },
       :caption => 'BSC',
       :param => :project_id
end
