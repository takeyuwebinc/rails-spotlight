# frozen_string_literal: true

module Tools
  class CreateWorkHourProjectTool < MCP::Tool
    description "Create a new work hour project"

    input_schema(
      properties: {
        code: {
          type: "string",
          description: "Project code (unique identifier)"
        },
        name: {
          type: "string",
          description: "Project name"
        },
        client_code: {
          type: "string",
          description: "Client code (optional)"
        },
        color: {
          type: "string",
          description: "Display color in hex format (default: #6366f1)"
        },
        start_date: {
          type: "string",
          description: "Start date (YYYY-MM-DD)"
        },
        end_date: {
          type: "string",
          description: "End date (YYYY-MM-DD)"
        }
      },
      required: [ "code", "name" ]
    )

    DEFAULT_COLOR = "#6366f1"

    def self.call(code:, name:, client_code: nil, color: nil, start_date: nil, end_date: nil, server_context:)
      # Check for duplicate code
      if WorkHour::Project.exists?(code: code)
        return MCP::Tool::Response.new([ {
          type: "text",
          text: "Error: Project with code '#{code}' already exists."
        } ])
      end

      # Find client if specified
      client = nil
      if client_code.present?
        client = WorkHour::Client.find_by(code: client_code)
        unless client
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Error: Client with code '#{client_code}' not found."
          } ])
        end
      end

      project = WorkHour::Project.new(
        code: code,
        name: name,
        client: client,
        color: color || DEFAULT_COLOR,
        status: :active,
        start_date: start_date.present? ? Date.parse(start_date) : nil,
        end_date: end_date.present? ? Date.parse(end_date) : nil
      )

      if project.save
        client_display = project.client&.name || "(no client)"
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Project created successfully:\n" \
                "- Code: #{project.code}\n" \
                "- Name: #{project.name}\n" \
                "- Client: #{client_display}\n" \
                "- Color: #{project.color}\n" \
                "- Status: #{project.status}"
        } ])
      else
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Error: #{project.errors.full_messages.join(', ')}"
        } ])
      end
    rescue => e
      MCP::Tool::Response.new([ {
        type: "text",
        text: "Error creating project: #{e.message}"
      } ])
    end
  end
end
