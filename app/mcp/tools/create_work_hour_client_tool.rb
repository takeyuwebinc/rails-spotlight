# frozen_string_literal: true

module Tools
  class CreateWorkHourClientTool < MCP::Tool
    description "Create a new work hour client"

    input_schema(
      properties: {
        code: {
          type: "string",
          description: "Client code (unique identifier)"
        },
        name: {
          type: "string",
          description: "Client name"
        }
      },
      required: [ "code", "name" ]
    )

    def self.call(code:, name:, server_context:)
      # Check for duplicate code
      if WorkHour::Client.exists?(code: code)
        return MCP::Tool::Response.new([ {
          type: "text",
          text: "Error: Client with code '#{code}' already exists."
        } ])
      end

      client = WorkHour::Client.new(code: code, name: name)

      if client.save
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Client created successfully:\n" \
                "- Code: #{client.code}\n" \
                "- Name: #{client.name}"
        } ])
      else
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Error: #{client.errors.full_messages.join(', ')}"
        } ])
      end
    rescue => e
      MCP::Tool::Response.new([ {
        type: "text",
        text: "Error creating client: #{e.message}"
      } ])
    end
  end
end
