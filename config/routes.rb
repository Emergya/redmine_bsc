scope '/projects/:project_id' do
  match '/management' => 'bsc_management#index', :via => [:get, :post, :put, :patch]
  get '/metrics' => 'bsc_metrics#index'
  resources :checkpoints, :controller => 'bsc_checkpoints' do
    collection do
      match '/preview', :to => 'previews#checkpoint', :via => [:get, :post, :put, :patch]
    end
  end
end