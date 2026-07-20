# frozen_string_literal: true

module Tools
  class ListAdrClientsTool < MCP::Tool
    extend AdrManagementToolSupport

    description "List ADR management clients with their engagement counts"

    input_schema(
      properties: {},
      required: []
    )

    def self.call(server_context:)
      clients = AdrManagement::Client.includes(:engagements).ordered_by_code

      if clients.any?
        list = clients.map do |client|
          "- #{client.code} #{client.name} (engagements: #{client.engagements.size})"
        end.join("\n")
        text_response("Found #{clients.size} client(s):\n#{list}")
      else
        text_response("No ADR management clients found. create_adr_client_tool で作成できます。")
      end
    rescue => e
      text_response("Error listing clients: #{e.message}")
    end
  end
end
