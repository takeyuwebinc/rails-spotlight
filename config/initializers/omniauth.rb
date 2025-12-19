# frozen_string_literal: true

# OmniAuth configuration for multiple auth paths:
# - /admin/auth - Admin panel authentication
# - /oauth/auth - MCP OAuth authentication

# Default path prefix (used for failure endpoint)
OmniAuth.config.path_prefix = "/admin/auth"

# Admin authentication
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
           Rails.application.credentials.dig(:google, :client_id),
           Rails.application.credentials.dig(:google, :client_secret),
           {
             name: "google_oauth2",
             path_prefix: "/admin/auth",
             scope: "email,profile",
             prompt: "select_account",
             hd: "takeyuweb.co.jp" # Restrict to takeyuweb.co.jp domain
           }

  # MCP OAuth authentication (same Google provider, different path)
  provider :google_oauth2,
           Rails.application.credentials.dig(:google, :client_id),
           Rails.application.credentials.dig(:google, :client_secret),
           {
             name: "oauth_google",
             path_prefix: "/oauth/auth",
             scope: "email,profile",
             prompt: "select_account",
             hd: "takeyuweb.co.jp" # Restrict to takeyuweb.co.jp domain
           }
end

# Handle OmniAuth failures
OmniAuth.config.on_failure = proc { |env|
  OmniAuth::FailureEndpoint.new(env).redirect_to_failure
}
