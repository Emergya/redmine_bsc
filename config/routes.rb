scope '/projects/:project_id' do
  match '/change_metric' => 'bsc_metrics#change_metric', :via => [:get, :post, :put, :patch]
  match '/management' => 'bsc_management#index', :via => [:get, :post, :put, :patch]
  get '/metrics' => 'bsc_metrics#index'
  resources :checkpoints, :controller => 'bsc_checkpoints' do
    collection do
      match '/preview', :to => 'previews#checkpoint', :via => [:get, :post, :put, :patch]
    end
  end
end