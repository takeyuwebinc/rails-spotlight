# frozen_string_literal: true

module Tools
  class UpdateSlideTool < MCP::Tool
    description "Update an existing slide by slug with new markdown content"

    input_schema(
      properties: {
        slug: {
          type: "string",
          description: "The slug of the slide to update"
        },
        content: {
          type: "string",
          description: "The new markdown content with YAML frontmatter and slide pages separated by ---"
        }
      },
      required: [ "slug", "content" ]
    )

    def self.call(slug:, content:, server_context:)
      # Find the existing slide
      slide = Slide.find_by(slug: slug)

      unless slide
        return MCP::Tool::Response.new([ {
          type: "text",
          text: "Slide not found with slug: #{slug}"
        } ])
      end

      # Update the slide with new content
      updated_slide = Slide.import_from_markdown(content)

      if updated_slide
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Slide updated successfully:\n" \
                "- Title: #{updated_slide.title}\n" \
                "- Slug: #{updated_slide.slug}\n" \
                "- Published at: #{updated_slide.published_at}\n" \
                "- Pages: #{updated_slide.page_count}\n" \
                "- Tags: #{updated_slide.tags.pluck(:name).join(', ')}"
        } ])
      else
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Failed to update slide. Please check the markdown content and ensure it has valid YAML frontmatter and category: slide."
        } ])
      end
    rescue => e
      MCP::Tool::Response.new([ {
        type: "text",
        text: "Error updating slide: #{e.message}"
      } ])
    end
  end
end
