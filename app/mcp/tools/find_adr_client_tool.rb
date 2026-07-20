# frozen_string_literal: true

module Tools
  class FindAdrClientTool < MCP::Tool
    extend AdrManagementToolSupport

    description "Find an ADR management client by code or name"

    input_schema(
      properties: {
        query: {
          type: "string",
          description: "Search keyword (code or name)"
        }
      },
      required: [ "query" ]
    )

    def self.call(query:, server_context:)
      client = find_client(query)

      unless client
        return text_response(
          "Client not found for query: #{query}\n" \
          "list_adr_clients_tool で一覧を確認し、存在しなければ create_adr_client_tool で作成してください。"
        )
      end

      engagements = client.engagements.order(:code)
      engagements_list = if engagements.any?
        engagements.map { |engagement| "  - #{engagement.code}: #{engagement.name}" }.join("\n")
      else
        "  (no engagements)"
      end

      text_response(
        "Found client:\n" \
        "- Code: #{client.code}\n" \
        "- Name: #{client.name}\n" \
        "- Engagements:\n#{engagements_list}"
      )
    rescue => e
      text_response("Error finding client: #{e.message}")
    end

    def self.find_client(query)
      AdrManagement::Client.find_by_code(query) ||
        AdrManagement::Client.joins(:shared_client).where("clients.code LIKE ?", "#{query}%").first ||
        AdrManagement::Client.joins(:shared_client).where("clients.name LIKE ?", "%#{query}%").first
    end
  end
end
