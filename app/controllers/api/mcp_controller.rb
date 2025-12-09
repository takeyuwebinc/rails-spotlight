# frozen_string_literal: true

module Api
  class McpController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :authenticate_mcp_request

    def handle
      # Create MCP server instance
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
      token = request.headers["Authorization"]&.gsub(/^Bearer\s+/, "")
      expected_token = Rails.application.credentials.dig(:mcp, :api_token)

      unless token.present? && ActiveSupport::SecurityUtils.secure_compare(token, expected_token)
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
    end
  end
end
