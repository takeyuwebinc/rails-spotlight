# frozen_string_literal: true

module Tools
  class CreateProjectTool < MCP::Tool
    description "Create a new project from markdown content with YAML frontmatter"

    input_schema(
      properties: {
        content: {
          type: "string",
          description: "The markdown content with YAML frontmatter (including title, category: project, icon, color, technologies, position, published_date)"
        }
      },
      required: [ "content" ]
    )

    def self.call(content:, server_context:)
      project = Project.import_from_markdown(content)

      if project
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Project created successfully:\n" \
                "- Title: #{project.title}\n" \
                "- Icon: #{project.icon}\n" \
                "- Color: #{project.color}\n" \
                "- Technologies: #{project.technologies}\n" \
                "- Position: #{project.position}\n" \
                "- Published at: #{project.published_at}"
        } ])
      else
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Failed to create project. Please check the markdown content and ensure it has valid YAML frontmatter with required fields (title, icon, color, technologies, position, published_date) and category: project."
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
