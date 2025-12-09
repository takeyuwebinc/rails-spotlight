# frozen_string_literal: true

module Tools
  class FindProjectTool < MCP::Tool
    description "Find a project by title and return its details"

    input_schema(
      properties: {
        title: {
          type: "string",
          description: "The title of the project to find"
        }
      },
      required: [ "title" ]
    )

    def self.call(title:, server_context:)
      project = Project.find_by(title: title)

      if project
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Project found:\n" \
                "- Title: #{project.title}\n" \
                "- Icon: #{project.icon}\n" \
                "- Color: #{project.color}\n" \
                "- Technologies: #{project.technologies}\n" \
                "- Position: #{project.position}\n" \
                "- Published at: #{project.published_at}\n" \
                "- Description:\n#{project.description}\n" \
                "- Created at: #{project.created_at}\n" \
                "- Updated at: #{project.updated_at}"
        } ])
      else
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Project not found with title: #{title}"
        } ])
      end
    rescue => e
      MCP::Tool::Response.new([ {
        type: "text",
        text: "Error finding project: #{e.message}"
      } ])
    end
  end
end
