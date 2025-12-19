# frozen_string_literal: true

module Oauth
  class DiscoveryController < ApplicationController
    skip_before_action :verify_authenticity_token

    # GET /.well-known/oauth-protected-resource
    # RFC 9728: authorization_servers should contain issuer URLs, not metadata URLs
    # The client will append /.well-known/oauth-authorization-server to discover metadata
    def protected_resource
      render json: {
        resource: mcp_resource_url,
        authorization_servers: [ authorization_server_url ],
        scopes_supported: [ "mcp" ],
        bearer_methods_supported: [ "header" ]
      }
    end

    # GET /.well-known/oauth-authorization-server
    # Note: registration_endpoint is omitted - DCR is disabled
    # Clients must be pre-registered via Rails console
    def authorization_server
      render json: {
        issuer: authorization_server_url,
        authorization_endpoint: oauth_authorization_url,
        token_endpoint: oauth_token_url,
        scopes_supported: [ "mcp" ],
        response_types_supported: [ "code" ],
        response_modes_supported: [ "query" ],
        grant_types_supported: [ "authorization_code", "refresh_token" ],
        token_endpoint_auth_methods_supported: [ "client_secret_basic", "client_secret_post" ],
        code_challenge_methods_supported: [ "S256" ]
      }
    end

    private

    def mcp_resource_url
      api_mcp_url
    end

    def authorization_server_url
      root_url.chomp("/")
    end
  end
end
