include ActionView::Helpers::TextHelper

# Hash with roles replacement
ROLES_REPLACEMENT = {
  'administrador_proyecto' => [3, 29, 30, 31, 9], 
  'coordinador_proyecto' => [19, 6, 32, 11, 36, 20, 21, 23],
  'desarrollador' => [4, 10, 17],
  'usuario_externo' => [33, 14, 22, 7, 5, 12, 16, 18, 8, 34, 24, 15, 13, 25]
}
# Array with trackers to delete
# TRACKERS_TO_DELETE = [22,26,29,30,33,34,38,40,50,51,52,57,58,59]
TRACKERS_TO_DELETE = [22,26,30,33,34,40,50,51,52,57,58,59]
# Hash with issue statuses replacement
ISSUE_STATUSES_REPLACEMENT = {
  'facturable' => [14, 30]
}

namespace :redmine do
  namespace :emergya do
    namespace :roles do
      new_roles = {}
      desc "Apply role migration send by arguments"
      task :replace, [:roles] => :environment do |t, args|
        roles = args[:roles]

        roles.each do |name, old_roles|
        	if new_roles.include?(name)
        		new_role = new_roles[name]
        		old_roles.each do |old_role|
        			update_role(old_role, new_role)
        		end
        	end
        end
      end

      def update_role(irole, erole)
        role = Role.find(irole)
        new_role = Role.find(erole)

        # Role of members
        members = role.member_roles
        # Custom field visibility
        custom_fields = role.custom_fields
        # Different workflow settings
        workflows = role.workflow_rules + WorkflowPermission.where("role_id = ?", irole) + WorkflowTransition.where("role_id = ?", irole)
        # Custom queries visibility
        queries = Query.joins("join queries_roles ON query_id = id").where("role_id = ?", irole)

        puts "Replacing role #{role.name} with #{new_role.name}"
        # puts "#{irole.inspect}"
        # puts "#{erole.inspect}"
        # puts "Members: #{members.count}"
        # puts "Workflows: #{workflows.count}"
        # puts "Custom fields: #{custom_fields.count}"
        # puts "Queries: #{queries.count}"

        (members + workflows).each do |r|
          r.role_id = erole
          r.save
        end

        (custom_fields + queries).each do |cf|
          if !cf.roles.include?(new_role)
            cf.roles << new_role
          end
          cf.roles.delete(role)
        end

        # New project user role setting
        if Setting.new_project_user_role_id.present? and Setting.new_project_user_role_id == irole.to_s
         Setting.new_project_user_role_id = erole.to_s
        end

        # # Project manager CPM plugin setting
        # if Setting.plugin_redmine_cpm.present? and Setting.plugin_redmine_cpm['project_manager_role'].include?(irole.to_s) and !Setting.plugin_redmine_cpm['project_manager_role'].include?(erole.to_s)
        #  Setting.plugin_redmine_cpm['project_manager_role'].delete(irole.to_s)
        #  Setting.plugin_redmine_cpm['project_manager_role'] << erole.to_s
        #  Setting.set_from_params "plugin_redmine_cpm", Setting.plugin_redmine_cpm
        # end

        # puts "Members: #{members.count}"
        # puts "Workflows: #{workflows.count}"
        # puts "Custom fields: #{custom_fields.count}"
        # puts "Queries: #{queries.count}"

        # Remove current role from Redmine
        role.delete
      end

      task :create => :environment do
      	puts "Creating 'Administrador de proyecto' profile"
      	new_roles['administrador_proyecto'] = Role.create({
      		name: 'Administrador de proyecto', 
      		permissions: [:add_project, :edit_project, :select_project_modules, :manage_members, :manage_versions, :add_subprojects, :cpm_management, :km_user_knowledges, :km_knowledge_search, :manage_public_agile_queries, :manage_agile_verions, :add_agile_queries, :view_agile_queries, :view_agile_charts, :manage_boards, :add_messages, :edit_messages, :edit_own_messages, :delete_messages, :delete_own_messages, :view_calendar, :cmi_management, :cmi_view_metrics, :cmi_view_yearly, :cmi_project_info, :cmi_add_checkpoints, :cmi_edit_checkpoints, :cmi_add_checkpoint_notes, :cmi_edit_checkpoint_notes, :cmi_edit_own_checkpoint_notes, :cmi_view_checkpoints, :cmi_delete_checkpoints, :add_documents, :edit_documents, :delete_documents, :view_documents, :manage_files, :view_files, :view_gantt, :import, :manage_categories, :view_issues, :add_issues, :edit_issues, :manage_issue_relations, :manage_subtasks, :set_issues_private, :set_own_issues_private, :add_issue_notes, :edit_issue_notes, :edit_own_issue_notes, :view_private_notes, :set_notes_private, :move_issues, :delete_issues, :manage_public_queries, :save_queries, :view_issue_watchers, :add_issue_watchers, :delete_issue_watchers, :manage_news, :comment_news, :manage_repository, :browse_repository, :view_changesets, :commit_access, :manage_related_issues, :view_response_time, :view_stuff_to_do, :view_others_stuff_to_do, :view_all_users_stuff_to_do, :log_time, :view_time_entries, :edit_time_entries, :edit_own_time_entries, :manage_project_activities, :view_mt, :version_burndown_charts_view, :manage_wiki, :rename_wiki_pages, :delete_wiki_pages, :view_wiki_pages, :export_wiki_pages, :view_wiki_edits, :edit_wiki_pages, :delete_wiki_pages_attachments, :protect_wiki_pages], 
      		issues_visibility: 'all', 
      		users_visibility: 'all', 
      		time_entries_visibility: 'all',	
      		all_roles_managed: 1
      	})[:id]

      	puts "Creating 'Coordinador de proyecto' profile"
				new_roles['coordinador_proyecto'] = Role.create({
      		name: 'Coordinador de proyecto', 
      		permissions: [:edit_project, :select_project_modules, :manage_members, :manage_versions, :km_user_knowledges, :manage_public_agile_queries, :manage_agile_verions, :add_agile_queries, :view_agile_queries, :view_agile_charts, :manage_boards, :add_messages, :edit_messages, :edit_own_messages, :delete_messages, :delete_own_messages, :view_calendar, :add_documents, :edit_documents, :delete_documents, :view_documents, :manage_files, :view_files, :view_gantt, :import, :manage_categories, :view_issues, :add_issues, :edit_issues, :manage_issue_relations, :manage_subtasks, :set_issues_private, :set_own_issues_private, :add_issue_notes, :edit_issue_notes, :edit_own_issue_notes, :view_private_notes, :set_notes_private, :move_issues, :delete_issues, :manage_public_queries, :save_queries, :view_issue_watchers, :add_issue_watchers, :delete_issue_watchers, :manage_news, :comment_news, :manage_repository, :browse_repository, :view_changesets, :commit_access, :manage_related_issues, :view_response_time, :view_stuff_to_do, :log_time, :view_time_entries, :edit_time_entries, :edit_own_time_entries, :manage_project_activities, :view_mt, :version_burndown_charts_view, :manage_wiki, :rename_wiki_pages, :delete_wiki_pages, :view_wiki_pages, :export_wiki_pages, :view_wiki_edits, :edit_wiki_pages, :delete_wiki_pages_attachments, :protect_wiki_pages],
      		issues_visibility: 'all', 
      		users_visibility: 'all', 
      		time_entries_visibility: 'all',	
      		all_roles_managed: 1
      	})[:id]

      	puts "Creating 'Desarrollador' profile"
				new_roles['desarrollador'] = Role.create({
      		name: 'Desarrollador', 
      		permissions: [:manage_agile_verions, :add_agile_queries, :view_agile_queries, :view_agile_charts, :add_messages, :edit_own_messages, :delete_own_messages, :view_calendar, :add_documents, :edit_documents, :delete_documents, :view_documents, :manage_files, :view_files, :view_gantt, :import, :view_issues, :add_issues, :edit_issues, :manage_issue_relations, :manage_subtasks, :set_own_issues_private, :add_issue_notes, :edit_own_issue_notes, :view_private_notes, :set_notes_private, :delete_issues, :save_queries, :view_issue_watchers, :add_issue_watchers, :delete_issue_watchers, :comment_news, :browse_repository, :view_changesets, :commit_access, :manage_related_issues, :view_response_time, :view_stuff_to_do, :log_time, :view_time_entries, :edit_own_time_entries, :view_mt, :version_burndown_charts_view, :rename_wiki_pages, :delete_wiki_pages, :view_wiki_pages, :export_wiki_pages, :view_wiki_edits, :edit_wiki_pages, :delete_wiki_pages_attachments, :protect_wiki_pages], 
      		issues_visibility: 'all', 
      		users_visibility: 'all', 
      		time_entries_visibility: 'all',	
      		all_roles_managed: 1
      	})[:id]

      	puts "Creating 'Usuario externo' profile"
				new_roles['usuario_externo'] = Role.create({
      		name: 'Usuario externo', 
      		permissions: [:view_agile_queries, :view_agile_charts, :view_calendar, :view_gantt, :view_issues, :manage_subtasks, :save_queries, :view_issue_watchers, :version_burndown_charts_view], 
      		issues_visibility: 'default', 
      		users_visibility: 'all', 
      		time_entries_visibility: 'all',	
      		all_roles_managed: 1
      	})[:id]

      	puts "Creating auxiliar profiles"
      	Role.create({
      		name: 'Control de tiempo', 
      		permissions: [:log_time, :view_time_entries, :edit_own_time_entries],
      		issues_visibility: 'default', 
      		users_visibility: 'all', 
      		time_entries_visibility: 'all',	
      		all_roles_managed: 1
      	})

      	Role.create({
      		name: 'Crear peticiones', 
      		permissions: [:add_issues, :add_issue_watchers, :delete_issue_watchers],
      		issues_visibility: 'default', 
      		users_visibility: 'all', 
      		time_entries_visibility: 'all',	
      		all_roles_managed: 1
      	})

      	Role.create({
      		name: 'Editar peticiones', 
      		permissions: [:edit_issues, :manage_issue_relations, :add_issue_notes, :edit_own_issue_notes, :add_issue_watchers, :delete_issue_watchers],
      		issues_visibility: 'default', 
      		users_visibility: 'all', 
      		time_entries_visibility: 'all',	
      		all_roles_managed: 1
      	})

      	Role.create({
      		name: 'Gestionar peticiones', 
      		permissions: [:manage_agile_verions, :add_issues, :edit_issues, :manage_issue_relations, :add_issue_notes, :edit_own_issue_notes, :move_issues, :delete_issues, :add_issue_watchers, :delete_issue_watchers],
      		issues_visibility: 'default', 
      		users_visibility: 'all', 
      		time_entries_visibility: 'all',	
      		all_roles_managed: 1
      	})

      	Role.create({
      		name: 'Ver wiki', 
      		permissions: [:view_wiki_pages, :export_wiki_pages, :view_wiki_edits],
      		issues_visibility: 'default', 
      		users_visibility: 'all', 
      		time_entries_visibility: 'all',	
      		all_roles_managed: 1
      	})

      	Role.create({
      		name: 'Editar wiki', 
      		permissions: [:rename_wiki_pages, :delete_wiki_pages, :view_wiki_pages, :export_wiki_pages, :view_wiki_edits, :edit_wiki_pages, :delete_wiki_pages_attachments],
      		issues_visibility: 'default', 
      		users_visibility: 'all', 
      		time_entries_visibility: 'all',	
      		all_roles_managed: 1
      	})

      	Role.create({
      		name: 'Ficheros y documentos', 
      		permissions: [:add_documents, :edit_documents, :delete_documents, :view_documents, :manage_files, :view_files],
      		issues_visibility: 'default', 
      		users_visibility: 'all', 
      		time_entries_visibility: 'all',	
      		all_roles_managed: 1
      	})
      end

      task :migrate do
      	Rake::Task["redmine:emergya:roles:create"].invoke
        Rake::Task["redmine:emergya:roles:replace"].invoke(ROLES_REPLACEMENT)
      end
    end

    namespace :trackers do
    	default_tracker = 0
      desc "Apply tracker migration send by arguments"
      task :replace, [:trackers] => :environment do |t, args|
        trackers_id = args[:trackers]

        trackers = Tracker.find(trackers_id)
        new_tracker = Tracker.find(default_tracker)

        agile_colors = AgileColor.where("container_type = ? AND container_id IN (?)", 'Tracker', trackers_id)

        puts "Replacing trackers agile colors"
        color = ""
        agile_colors.each do |ac|
          color = ac.color if ac.color.present?
          ac.delete
        end
        AgileColor.create({container_id: default_tracker, container_type: 'Tracker', color: color})

        # custom_fields = trackers.map(&:custom_fields).flatten.uniq
        # new_tracker.custom_fields += custom_fields

        puts "Replacing trackers issues"
        issues = Issue.where("tracker_id IN (?)", trackers_id)
        issues.each do |i|
          #i.tracker_id = new_tracker_id
          #i.save(:validate => false)
          # i.update_column(:tracker_id, default_tracker)
          i.update_columns({:subject => sanitize("[#{i.tracker.name}] "+i.subject).truncate(255) ,:tracker_id => default_tracker})       
        end

        puts "Replacing trackers journal details"
        old_journal_details = JournalDetail.where("prop_key = ? AND old_value IN (?)", 'tracker_id', trackers_id)
        journal_details = JournalDetail.where("prop_key = ? AND value IN (?)", 'tracker_id', trackers_id)
        old_journal_details.each do |jd|
          jd.old_value = default_tracker
          jd.save
        end
        journal_details.each do |jd|
          jd.value = default_tracker
          jd.save
        end

        # projects = trackers.map(&:projects).flatten.uniq
        # new_tracker.projects += projects

        # workflows = trackers.map(&:workflow_rules) + WorkflowPermission.where("tracker_id IN (?)", trackers_id) + WorkflowTransition.where("tracker_id IN (?)", trackers_id)
        # workflows.flatten.uniq.each do |w|
        #   w.tracker_id = new_tracker_id
        #   w.save
        # end

        new_tracker.save

        puts "Deleting trackers"
        trackers.each do |t|
          t.destroy
        end
      end

      task :create => :environment do
    		default_tracker = Tracker.find_or_create_by({
    			name: 'Undefined',
    			is_in_chlog: 0,
    			default_status_id: 1,
    			is_in_roadmap: 0
    		})[:id]
    	end

      task :migrate do
      	Rake::Task["redmine:emergya:trackers:create"].invoke
        Rake::Task["redmine:emergya:trackers:replace"].invoke(TRACKERS_TO_DELETE)
      end
    end

    namespace :issue_statuses do
      new_statuses = {}
      desc "Apply issue status migration send by arguments"
      task :replace, [:statuses] => :environment do |t, args|
        statuses = args[:statuses]

        statuses.each do |name, old_statuses|
          if new_statuses.include?(name)
            new_status = new_statuses[name]
            old_statuses.each do |old_status|
              update_status(old_status, new_status)
            end
          end
        end
      end

      def update_status(istatus, estatus)
        status = IssueStatus.find(istatus)
        new_status = IssueStatus.find(estatus)

        puts "Replacing issue status #{status.name} with #{new_status.name}"
        # Update issues 
        Issue.where(status_id: status.id).update_all(:status_id => new_status.id)
        # Update journal details 
        JournalDetail.where("property = ? AND prop_key = ? AND old_value = ?", 'attr', 'status_id', status.id).update_all(:old_value => new_status.id)
        JournalDetail.where("property = ? AND prop_key = ? AND value = ?", 'attr', 'status_id', status.id).update_all(:value => new_status.id)
        # Update workflows
        workflow_permission_old = WorkflowPermission.where(old_status_id: status.id).update_all(:old_status_id => new_status.id)
        workflow_permission_new = WorkflowPermission.where(new_status_id: status.id).update_all(:new_status_id => new_status.id)
        workflow_rule_old = WorkflowRule.where(old_status_id: status.id).update_all(:old_status_id => new_status.id)
        workflow_rule_new = WorkflowRule.where(new_status_id: status.id).update_all(:new_status_id => new_status.id)
        workflow_transition_old = WorkflowTransition.where(old_status_id: status.id).update_all(:old_status_id => new_status.id)
        workflow_transition_new = WorkflowTransition.where(new_status_id: status.id).update_all(:new_status_id => new_status.id)
        
        status.delete
      end

      task :create => :environment do
        puts "Creating 'Facturable' status"
        new_statuses['facturable'] = IssueStatus.create({
          name: 'Facturable', 
          is_closed: 1
        })[:id]
      end

      task :migrate do
        Rake::Task["redmine:emergya:issue_statuses:create"].invoke
        Rake::Task["redmine:emergya:issue_statuses:replace"].invoke(ISSUE_STATUSES_REPLACEMENT)
      end
    end

    task :migrate do
      Rake::Task["redmine:emergya:roles:migrate"].invoke
      Rake::Task["redmine:emergya:trackers:migrate"].invoke
      #Rake::Task["redmine:emergya:issue_statuses:migrate"].invoke
    end
  end
end