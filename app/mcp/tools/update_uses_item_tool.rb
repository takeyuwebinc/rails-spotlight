# frozen_string_literal: true

module Tools
  class UpdateUsesItemTool < MCP::Tool
    description "Update an existing uses item by slug with new markdown content"

    input_schema(
      properties: {
        slug: {
          type: "string",
          description: "The slug of the uses item to update"
        },
        content: {
          type: "string",
          description: "The new markdown content with YAML frontmatter"
        }
      },
      required: [ "slug", "content" ]
    )

    def self.call(slug:, content:, server_context:)
      # Find the existing uses item
      uses_item = UsesItem.find_by(slug: slug)

      unless uses_item
        return MCP::Tool::Response.new([ {
          type: "text",
          text: "Uses item not found with slug: #{slug}"
        } ])
      end

      # Update the uses item with new content
      updated_item = UsesItem.import_from_markdown(content)

      if updated_item
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Uses item updated successfully:\n" \
                "- Name: #{updated_item.name}\n" \
                "- Slug: #{updated_item.slug}\n" \
                "- Category: #{updated_item.category}\n" \
                "- URL: #{updated_item.url || 'N/A'}\n" \
                "- Position: #{updated_item.position}\n" \
                "- Published: #{updated_item.published}\n" \
                "- Discontinued: #{updated_item.discontinued}"
        } ])
      else
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Failed to update uses item. Please check the markdown content and ensure it has valid YAML frontmatter and category: uses_item."
        } ])
      end
    rescue => e
      MCP::Tool::Response.new([ {
        type: "text",
        text: "Error updating uses item: #{e.message}"
      } ])
    end
  end
end
