# frozen_string_literal: true

module Tools
  class FindUsesItemTool < MCP::Tool
    description "Find a uses item by slug and return its details"

    input_schema(
      properties: {
        slug: {
          type: "string",
          description: "The slug of the uses item to find"
        }
      },
      required: [ "slug" ]
    )

    def self.call(slug:, server_context:)
      uses_item = UsesItem.find_by(slug: slug)

      if uses_item
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Uses item found:\n" \
                "- Name: #{uses_item.name}\n" \
                "- Slug: #{uses_item.slug}\n" \
                "- Category: #{uses_item.category}\n" \
                "- URL: #{uses_item.url || 'N/A'}\n" \
                "- Position: #{uses_item.position}\n" \
                "- Published: #{uses_item.published}\n" \
                "- Discontinued: #{uses_item.discontinued}\n" \
                "- Description:\n#{uses_item.description}\n" \
                "- Created at: #{uses_item.created_at}\n" \
                "- Updated at: #{uses_item.updated_at}"
        } ])
      else
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Uses item not found with slug: #{slug}"
        } ])
      end
    rescue => e
      MCP::Tool::Response.new([ {
        type: "text",
        text: "Error finding uses item: #{e.message}"
      } ])
    end
  end
end
