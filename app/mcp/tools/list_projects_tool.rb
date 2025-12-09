# frozen_string_literal: true

module Tools
  class ListProjectsTool < MCP::Tool
    description "List all projects with their basic information"

    input_schema(
      properties: {
        status: {
          type: "string",
          description: "Filter by status: 'published' or 'all' (default: 'all')",
          enum: [ "published", "all" ]
        }
      },
      required: []
    )

    def self.call(status: "all", server_context:)
      projects = case status
      when "published"
                   Project.published
      else
                   Project.ordered
      end

      if projects.any?
        project_list = projects.map do |project|
          "- #{project.title}\n" \
          "  Icon: #{project.icon}\n" \
          "  Color: #{project.color}\n" \
          "  Technologies: #{project.technologies}\n" \
          "  Position: #{project.position}\n" \
          "  Published at: #{project.published_at.strftime('%Y-%m-%d')}"
        end.join("\n\n")

        MCP::Tool::Response.new([ {
          type: "text",
          text: "Found #{projects.count} project(s):\n\n#{project_list}"
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
  end
end
