# frozen_string_literal: true

module Tools
  class CreateAdrEngagementTool < MCP::Tool
    extend AdrManagementToolSupport

    description "Create an ADR management engagement under a client"

    input_schema(
      properties: {
        code: {
          type: "string",
          description: "Engagement code (unique identifier; used by coding agents to identify the engagement from the repository)"
        },
        name: {
          type: "string",
          description: "Engagement name (e.g. Fabble)"
        },
        client_code: {
          type: "string",
          description: "Code of the client this engagement belongs to"
        },
        description: {
          type: "string",
          description: "Optional description used as search context"
        }
      },
      required: [ "code", "name", "client_code" ]
    )

    def self.call(code:, name:, client_code:, description: nil, server_context:)
      client = AdrManagement::Client.find_by_code(client_code)
      unless client
        return error_response(AdrManagement::OperationError.build(
          kind: :master_not_found,
          param: "client_code",
          message: "クライアント（code: #{client_code}）が存在しません",
          next_action: "list_adr_clients_tool で表記揺れがないか確認し、" \
                       "存在しなければ create_adr_client_tool で作成してください"
        ))
      end

      engagement = client.engagements.new(code: code, name: name, description: description)

      if engagement.save
        text_response(
          "Engagement created successfully:\n" \
          "- Code: #{engagement.code}\n" \
          "- Name: #{engagement.name}\n" \
          "- Client: #{client.name}"
        )
      else
        error_response(engagement.errors.map do |error|
          AdrManagement::OperationError.build(
            kind: :invalid_input,
            param: error.attribute.to_s,
            message: error.full_message,
            next_action: "list_adr_engagements_tool で既存案件を確認してください"
          )
        end)
      end
    rescue => e
      text_response("Error creating engagement: #{e.message}")
    end
  end
end
