# frozen_string_literal: true

module Tools
  class CreateUsesItemTool < MCP::Tool
    description "Create a new uses item from markdown content with YAML frontmatter"

    input_schema(
      properties: {
        content: {
          type: "string",
          description: "The markdown content with YAML frontmatter (including name, slug, category: uses_item, item_category, url, position, published, discontinued)"
        }
      },
      required: [ "content" ]
    )

    def self.call(content:, server_context:)
      uses_item = UsesItem.import_from_markdown(content)

      if uses_item
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Uses item created successfully:\n" \
                "- Name: #{uses_item.name}\n" \
                "- Slug: #{uses_item.slug}\n" \
                "- Category: #{uses_item.category}\n" \
                "- URL: #{uses_item.url || 'N/A'}\n" \
                "- Position: #{uses_item.position}\n" \
                "- Published: #{uses_item.published}\n" \
                "- Discontinued: #{uses_item.discontinued}"
        } ])
      else
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Failed to create uses item. Please check the markdown content and ensure it has valid YAML frontmatter with required fields (name, slug, item_category, url, position) and category: uses_item."
        } ])
      end
    rescue => e
      MCP::Tool::Response.new([ {
        type: "text",
        text: "Error creating uses item: #{e.message}"
      } ])
    end
  end
end
