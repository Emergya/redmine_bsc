scope '/projects/:project_id' do
  match '/change_metric' => 'bsc_metrics#change_metric', :via => [:get, :post, :put, :patch]
  match '/management' => 'bsc_management#index', :via => [:get, :post, :put, :patch]
  match '/management/delete' => 'bsc_management#destroy', :via => :delete
  get '/metrics' => 'bsc_metrics#index'
  match '/checkpoints/new_without_annualization', :to => 'bsc_checkpoints#new_without_annualization', :via => [:get, :post, :put, :patch]
  match '/checkpoints/create_without_annualization', :to => 'bsc_checkpoints#create_without_annualization', :via => [:get, :post, :put, :patch]
  resources :checkpoints, :controller => 'bsc_checkpoints' do
    collection do
      match '/preview', :to => 'previews#checkpoint', :via => [:get, :post, :put, :patch]
    end
  end
end

match '/settings/show_tracker_custom_fields' => 'settings#show_tracker_custom_fields', :via => [:get, :post]
match '/settings/show_tracker_statuses' => 'settings#show_tracker_statuses', :via => [:get, :post]
match 'projects/:id/setting_bsc_manage_dates' => 'projects#setting_bsc_manage_dates', via: [:post, :put], :as => 'projects_setting_bsc_manage_dates'
