# frozen_string_literal: true

module Api
  class McpController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :authenticate_mcp_request

    def handle
      # Create MCP server instance with OAuth user context
      server = ContentServer.create

      # Handle the JSON-RPC request
      response = server.handle_json(request.raw_post)

      # Return response
      render json: response
    rescue => e
      Rails.logger.error "MCP Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      render json: {
        jsonrpc: "2.0",
        error: {
          code: -32603,
          message: "Internal error",
          data: { details: e.message }
        },
        id: nil
      }, status: :internal_server_error
    end

    private

    def authenticate_mcp_request
      # Try OAuth token first (Doorkeeper)
      if doorkeeper_token_valid?
        return
      end

      # Fall back to legacy static token for backwards compatibility
      if legacy_token_valid?
        return
      end

      # No valid authentication
      render_unauthorized
    end

    def doorkeeper_token_valid?
      token = request.headers["Authorization"]&.gsub(/^Bearer\s+/, "")
      return false if token.blank?

      @doorkeeper_token = Doorkeeper::AccessToken.by_token(token)
      return false unless @doorkeeper_token

      @doorkeeper_token.accessible?
    end

    def legacy_token_valid?
      token = request.headers["Authorization"]&.gsub(/^Bearer\s+/, "")
      expected_token = Rails.application.credentials.dig(:mcp, :api_token)

      return false if token.blank? || expected_token.blank?

      ActiveSupport::SecurityUtils.secure_compare(token, expected_token)
    end

    def render_unauthorized
      response.headers["WWW-Authenticate"] = %(Bearer resource_metadata="#{oauth_protected_resource_url}")
      render json: {
        jsonrpc: "2.0",
        error: {
          code: -32603,
          message: "Unauthorized",
          data: { details: "Invalid or missing authentication token" }
        },
        id: params[:id]
      }, status: :unauthorized
    end

    def oauth_protected_resource_url
      "#{request.base_url}/.well-known/oauth-protected-resource"
    end
  end
end
