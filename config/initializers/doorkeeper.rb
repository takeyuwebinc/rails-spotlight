# frozen_string_literal: true

Doorkeeper.configure do
  # ORM configuration
  orm :active_record

  # Resource owner authentication via session (set by OmniAuth Google callback)
  # Only @takeyuweb.co.jp accounts can authorize MCP clients
  # Doorkeeper expects resource_owner to respond to :id
  resource_owner_authenticator do
    if session[:oauth_email].present?
      # Return an object that responds to :id (email address as ID)
      OpenStruct.new(id: session[:oauth_email])
    else
      # Store the current authorization URL to return after Google authentication
      session[:oauth_return_to] = request.fullpath
      redirect_to oauth_login_path
    end
  end

  # Resource owner from credentials (for token endpoint)
  resource_owner_from_credentials do |_routes|
    # Not used - we use authorization code flow only
    nil
  end

  # API mode for MCP server (no views needed for API endpoints)
  # Disabled because we need authorization views for the OAuth flow
  # api_only

  # Authorization Code expiration time
  authorization_code_expires_in 10.minutes

  # Access token expiration time (1 hour as per requirements)
  access_token_expires_in 1.hour

  # Enable refresh tokens (30 days as per requirements)
  use_refresh_token

  # Custom refresh token expiration
  custom_access_token_expires_in do |context|
    if context.grant_type == "refresh_token"
      1.hour
    else
      1.hour
    end
  end

  # Force PKCE for all clients (MCP spec requirement)
  force_pkce

  # Hash tokens for security
  hash_token_secrets
  hash_application_secrets

  # Grant flows - authorization_code only (with PKCE)
  grant_flows %w[authorization_code]

  # Default scopes for MCP access
  default_scopes :mcp
  optional_scopes :mcp

  # Force SSL in production
  force_ssl_in_redirect_uri { |uri| !Rails.env.development? && uri.host != "localhost" }

  # Allow localhost for development
  # forbid_redirect_uri { |uri| false }

  # Skip authorization for trusted applications (auto-approve)
  skip_authorization do |_resource_owner, client|
    # Auto-approve for known MCP clients (Claude)
    client.name&.include?("Claude") || false
  end

  # Base controller
  base_controller "ApplicationController"
end
