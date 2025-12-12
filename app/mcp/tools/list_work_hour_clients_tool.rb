# frozen_string_literal: true

module Tools
  class ListWorkHourClientsTool < MCP::Tool
    description "List all work hour clients with their project counts"

    input_schema(
      properties: {},
      required: []
    )

    def self.call(server_context:)
      clients = WorkHour::Client.includes(:projects).order(:code)

      if clients.any?
        client_list = clients.map do |client|
          "- #{client.code} #{client.name} (projects: #{client.projects.size})"
        end.join("\n")

        MCP::Tool::Response.new([ {
          type: "text",
          text: "Found #{clients.count} client(s):\n#{client_list}"
        } ])
      else
        MCP::Tool::Response.new([ {
          type: "text",
          text: "No clients found."
        } ])
      end
    rescue => e
      MCP::Tool::Response.new([ {
        type: "text",
        text: "Error listing clients: #{e.message}"
      } ])
    end
  end
end
