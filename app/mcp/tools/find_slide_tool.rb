# frozen_string_literal: true

module Tools
  class FindSlideTool < MCP::Tool
    description "Find a slide by slug and return its details"

    input_schema(
      properties: {
        slug: {
          type: "string",
          description: "The slug of the slide to find"
        }
      },
      required: [ "slug" ]
    )

    def self.call(slug:, server_context:)
      slide = Slide.find_by(slug: slug)

      if slide
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Slide found:\n" \
                "- Title: #{slide.title}\n" \
                "- Slug: #{slide.slug}\n" \
                "- URL: #{slide.public_url}\n" \
                "- Description: #{slide.description}\n" \
                "- Published at: #{slide.published_at}\n" \
                "- Pages: #{slide.page_count}\n" \
                "- Tags: #{slide.tags.pluck(:name).join(', ')}\n" \
                "- Status: #{slide.published? ? 'Published' : 'Draft'}\n" \
                "- Created at: #{slide.created_at}\n" \
                "- Updated at: #{slide.updated_at}"
        } ])
      else
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Slide not found with slug: #{slug}"
        } ])
      end
    rescue => e
      MCP::Tool::Response.new([ {
        type: "text",
        text: "Error finding slide: #{e.message}"
      } ])
    end
  end
end
