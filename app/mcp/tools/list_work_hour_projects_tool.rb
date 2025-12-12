# frozen_string_literal: true

module Tools
  class ListWorkHourProjectsTool < MCP::Tool
    description "List work hour projects with optional filtering by status and client"

    input_schema(
      properties: {
        status: {
          type: "string",
          description: "Filter by status: 'active', 'closed', or 'all' (default: 'active')",
          enum: [ "active", "closed", "all" ]
        },
        client_code: {
          type: "string",
          description: "Filter by client code"
        }
      },
      required: []
    )

    def self.call(status: "all", client_code: nil, server_context:)
      projects = WorkHour::Project.includes(:client)

      # Filter by status
      case status
      when "active"
        projects = projects.active
      when "closed"
        projects = projects.where(status: "closed")
      end

      # Filter by client
      if client_code.present?
        client = WorkHour::Client.find_by(code: client_code)
        projects = projects.where(client: client) if client
      end

      projects = projects.order(:code)

      if projects.any?
        project_list = projects.map do |project|
          client_name = project.client&.name || "(no client)"
          period = format_period(project.start_date, project.end_date)
          "- #{project.code}: #{project.name}\n" \
          "  Client: #{client_name}\n" \
          "  Status: #{project.status}\n" \
          "  Period: #{period}"
        end.join("\n")

        MCP::Tool::Response.new([ {
          type: "text",
          text: "Found #{projects.count} project(s):\n#{project_list}"
        } ])
      else
        MCP::Tool::Response.new([ {
          type: "text",
          text: "No projects found with the specified criteria."
        } ])
      end
    rescue => e
      MCP::Tool::Response.new([ {
        type: "text",
        text: "Error listing projects: #{e.message}"
      } ])
    end

    def self.format_period(start_date, end_date)
      return "Not set" if start_date.nil? && end_date.nil?

      start_str = start_date&.strftime("%Y-%m-%d") || "?"
      end_str = end_date&.strftime("%Y-%m-%d") || "?"
      "#{start_str} - #{end_str}"
    end
  end
end
