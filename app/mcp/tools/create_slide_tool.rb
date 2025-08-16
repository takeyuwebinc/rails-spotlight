# frozen_string_literal: true

module Tools
  class CreateSlideTool < MCP::Tool
    description "Create a new slide from markdown content with YAML frontmatter"

    input_schema(
      properties: {
        content: {
          type: "string",
          description: "The markdown content with YAML frontmatter (including title, slug, description, published_date, tags, etc.) and slide pages separated by ---"
        }
      },
      required: [ "content" ]
    )

    def self.call(content:, server_context:)
      slide = Slide.import_from_markdown(content)

      if slide
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Slide created successfully:\n" \
                "- Title: #{slide.title}\n" \
                "- Slug: #{slide.slug}\n" \
                "- Published at: #{slide.published_at}\n" \
                "- Pages: #{slide.page_count}\n" \
                "- Tags: #{slide.tags.pluck(:name).join(', ')}"
        } ])
      else
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Failed to create slide. Please check the markdown content and ensure it has valid YAML frontmatter with required fields (title, slug, description, published_date) and category: slide."
        } ])
      end
    rescue => e
      MCP::Tool::Response.new([ {
        type: "text",
        text: "Error creating slide: #{e.message}"
      } ])
    end
  end
end
