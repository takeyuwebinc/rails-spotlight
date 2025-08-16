# frozen_string_literal: true

module Tools
  class ListSlidesTool < MCP::Tool
    description "List all slides with their basic information"

    input_schema(
      properties: {
        status: {
          type: "string",
          description: "Filter by status: 'published', 'draft', or 'all' (default: 'all')",
          enum: [ "published", "draft", "all" ]
        },
        tag_slug: {
          type: "string",
          description: "Filter by tag slug (optional)"
        }
      },
      required: []
    )

    def self.call(status: "all", tag_slug: nil, server_context:)
      slides = case status
      when "published"
                 Slide.published
      when "draft"
                 Slide.draft
      else
                 Slide.all.order(published_at: :desc)
      end

      slides = slides.tagged_with(tag_slug) if tag_slug.present?

      if slides.any?
        slide_list = slides.map do |slide|
          "- #{slide.title}\n" \
          "  Slug: #{slide.slug}\n" \
          "  Pages: #{slide.page_count}\n" \
          "  Status: #{slide.published? ? 'Published' : 'Draft'}\n" \
          "  Published at: #{slide.published_at.strftime('%Y-%m-%d')}\n" \
          "  Tags: #{slide.tags.pluck(:name).join(', ')}"
        end.join("\n\n")

        MCP::Tool::Response.new([ {
          type: "text",
          text: "Found #{slides.count} slide(s):\n\n#{slide_list}"
        } ])
      else
        MCP::Tool::Response.new([ {
          type: "text",
          text: "No slides found with the specified criteria."
        } ])
      end
    rescue => e
      MCP::Tool::Response.new([ {
        type: "text",
        text: "Error listing slides: #{e.message}"
      } ])
    end
  end
end
