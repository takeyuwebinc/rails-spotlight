Rails.application.routes.draw do
  if Rails.env.local?
    mount Rswag::Ui::Engine => "/api-docs"
    mount Rswag::Api::Engine => "/api-docs/api"
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Legacy URL redirects
  get "/recruit", to: redirect("/", status: 301)
  get "/jobs", to: redirect("/", status: 301)
  get "/jobs/*path", to: redirect("/", status: 301)
  get "/aboutus", to: redirect("/about", status: 301)
  get "/company", to: redirect("/about", status: 301)
  get "/services", to: redirect("/projects", status: 301)
  get "/services/*path", to: redirect("/projects", status: 301)
  get "/works", to: redirect("/projects", status: 301)
  get "/works/*path", to: redirect("/projects", status: 301)
  get "/announcements", to: redirect("/", status: 301)
  get "/announcements/*path", to: redirect("/", status: 301)
  get "/contacts", to: redirect("/about", status: 301)

  # API routes
  namespace :api do
    resources :link_cards, only: [] do
      collection do
        get :metadata
      end
    end

    # MCP endpoint for article management
    post "mcp", to: "mcp#handle"
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

  # Slides
  resources :slides, only: [ :show ]

  # Tags
  get "tags/:slug/articles" => "tags#show", as: :tag_articles

  # Projects
  resources :projects, only: [ :index ]

  # Speaking engagements
  get "speaking" => "speaking#index"
  get "uses" => "uses#index"

  # Sitemap
  get "sitemap.xml" => "sitemaps#index", defaults: { format: "xml" }

  # llms.txt route
  get "llms.txt", to: "llms_txt#show", format: false, as: :llms_txt
end
