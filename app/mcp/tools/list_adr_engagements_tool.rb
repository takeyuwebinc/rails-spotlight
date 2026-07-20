# frozen_string_literal: true

module Tools
  class ListAdrEngagementsTool < MCP::Tool
    extend AdrManagementToolSupport

    description "List ADR management engagements (continuous development subjects that ADRs are recorded against), " \
                "optionally filtered by client code"

    input_schema(
      properties: {
        client_code: {
          type: "string",
          description: "Filter by client code"
        }
      },
      required: []
    )

    def self.call(client_code: nil, server_context:)
      engagements = AdrManagement::Engagement.includes(:adrs).order(:code)

      if client_code.present?
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
        engagements = engagements.where(client: client)
      end

      if engagements.any?
        list = engagements.map do |engagement|
          "- #{engagement.code}: #{engagement.name} (ADRs: #{engagement.adrs.size})"
        end.join("\n")
        text_response("Found #{engagements.size} engagement(s):\n#{list}")
      else
        text_response("No engagements found. create_adr_engagement_tool で作成できます。")
      end
    rescue => e
      text_response("Error listing engagements: #{e.message}")
    end
  end
end
