Rails.application.routes.draw do
  # Doorkeeper OAuth routes (without admin UI and DCR)
  use_doorkeeper do
    # Disable all admin controllers (applications management)
    skip_controllers :applications, :authorized_applications
  end

  # OAuth Discovery endpoints (MCP spec)
  get ".well-known/oauth-protected-resource", to: "oauth/discovery#protected_resource", as: :oauth_protected_resource
  get ".well-known/oauth-authorization-server", to: "oauth/discovery#authorization_server", as: :oauth_authorization_server_metadata

  # OAuth session routes (for MCP OAuth with Google authentication)
  namespace :oauth do
    get "login", to: "sessions#new", as: :login
    delete "logout", to: "sessions#destroy", as: :logout

    # OmniAuth callbacks for OAuth (using oauth_google provider)
    get "auth/oauth_google/callback", to: "omniauth_callbacks#oauth_google"
    get "auth/failure", to: "omniauth_callbacks#failure"
  end

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
  get "/works", to: redirect("/projects", status: 301)
  get "/works/*path", to: redirect("/projects", status: 301)
  get "/announcements", to: redirect("/", status: 301)
  get "/announcements/*path", to: redirect("/", status: 301)
  get "/contacts", to: redirect("/about", status: 301)

  # Legacy service URL redirects (old site compatibility)
  get "/service", to: redirect("/services", status: 301)
  get "/service/development", to: redirect("/services/outsourcing", status: 301)
  get "/service/consulting", to: redirect("/services/technical_advisor", status: 301)
  get "/service/ses", to: redirect("/services", status: 301)

  # API routes
  namespace :api do
    # MCP endpoint - POST for requests, GET for protocol discovery (MCP 2025-06-18)
    post "mcp", to: "mcp#handle"
    get "mcp", to: "mcp#handle"
    resources :link_cards, only: [] do
      collection do
        get :metadata
      end
    end
  end

  # Admin routes
  namespace :admin do
    # Authentication
    get "login", to: "sessions#new", as: :login
    delete "logout", to: "sessions#destroy", as: :logout

    # OmniAuth callbacks
    get "auth/google_oauth2/callback", to: "omniauth_callbacks#google_oauth2"
    get "auth/failure", to: "omniauth_callbacks#failure"

    root to: "dashboard#index"
    namespace :work_hour do
      resources :clients
      resources :projects do
        resources :monthly_estimates, only: %i[new create edit update destroy]
      end
      resources :work_entries
      resources :csv, only: [ :index ] do
        collection do
          post :import_projects
          post :import_work_entries
          get :export_work_entries
        end
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

  # Zenn Articles (Turbo Frame)
  get "zenn_articles" => "zenn_articles#index"

  # Slides
  resources :slides, only: [ :show ]

  # Services
  get "services" => "services#index"
  get "services/outsourcing" => "services#outsourcing"
  get "services/technical_advisor" => "services#technical_advisor"

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
