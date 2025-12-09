# frozen_string_literal: true

module Tools
  class UpdateProjectTool < MCP::Tool
    description "Update an existing project by title with new markdown content"

    input_schema(
      properties: {
        title: {
          type: "string",
          description: "The title of the project to update"
        },
        content: {
          type: "string",
          description: "The new markdown content with YAML frontmatter"
        }
      },
      required: [ "title", "content" ]
    )

    def self.call(title:, content:, server_context:)
      # Find the existing project
      project = Project.find_by(title: title)

      unless project
        return MCP::Tool::Response.new([ {
          type: "text",
          text: "Project not found with title: #{title}"
        } ])
      end

      # Update the project with new content
      updated_project = Project.import_from_markdown(content)

      if updated_project
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Project updated successfully:\n" \
                "- Title: #{updated_project.title}\n" \
                "- Icon: #{updated_project.icon}\n" \
                "- Color: #{updated_project.color}\n" \
                "- Technologies: #{updated_project.technologies}\n" \
                "- Position: #{updated_project.position}\n" \
                "- Published at: #{updated_project.published_at}"
        } ])
      else
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Failed to update project. Please check the markdown content and ensure it has valid YAML frontmatter and category: project."
        } ])
      end
    rescue => e
      MCP::Tool::Response.new([ {
        type: "text",
        text: "Error updating project: #{e.message}"
      } ])
    end
  end
end
