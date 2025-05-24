Rails.application.routes.draw do
  if Rails.env.local?
    mount Rswag::Ui::Engine => "/api-docs"
    mount Rswag::Api::Engine => "/api-docs/api"
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    resources :link_cards, only: [] do
      collection do
        get :metadata
      end
    end
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
  root "home#index"
  get "about" => "home#about"

  # Articles
  get "articles" => "articles#index"
  get "articles/:slug" => "articles#show", as: :article

  # Tags
  get "tags/:slug/articles" => "tags#show", as: :tag_articles

  # Projects
  resources :projects, only: [ :index ]

  # TODO: Add resources for speaking, and uses
  get "speaking" => "home#speaking"
  get "uses" => "home#uses"

  # Sitemap
  get "sitemap.xml" => "sitemaps#index", defaults: { format: "xml" }
end
