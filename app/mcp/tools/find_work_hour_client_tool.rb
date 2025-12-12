# frozen_string_literal: true

module Tools
  class FindWorkHourClientTool < MCP::Tool
    description "Find a work hour client by code or name"

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

      if client
        projects_list = if client.projects.any?
          client.projects.map do |project|
            "  - #{project.code}: #{project.name} (#{project.status})"
          end.join("\n")
        else
          "  (no projects)"
        end

        MCP::Tool::Response.new([ {
          type: "text",
          text: "Found client:\n" \
                "- Code: #{client.code}\n" \
                "- Name: #{client.name}\n" \
                "- Projects:\n#{projects_list}"
        } ])
      else
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Client not found for query: #{query}"
        } ])
      end
    rescue => e
      MCP::Tool::Response.new([ {
        type: "text",
        text: "Error finding client: #{e.message}"
      } ])
    end

    def self.find_client(query)
      # 1. Exact code match
      client = WorkHour::Client.find_by(code: query)
      return client if client

      # 2. Partial code match (prefix)
      client = WorkHour::Client.where("code LIKE ?", "#{query}%").first
      return client if client

      # 3. Name partial match
      WorkHour::Client.where("name LIKE ?", "%#{query}%").first
    end
  end
end
