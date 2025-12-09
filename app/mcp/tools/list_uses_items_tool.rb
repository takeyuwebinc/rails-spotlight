# frozen_string_literal: true

module Tools
  class ListUsesItemsTool < MCP::Tool
    description "List all uses items with their basic information"

    input_schema(
      properties: {
        status: {
          type: "string",
          description: "Filter by status: 'published' or 'all' (default: 'all')",
          enum: [ "published", "all" ]
        },
        category: {
          type: "string",
          description: "Filter by category (optional)"
        }
      },
      required: []
    )

    def self.call(status: "all", category: nil, server_context:)
      uses_items = case status
      when "published"
                     UsesItem.published.ordered
      else
                     UsesItem.ordered
      end

      uses_items = uses_items.by_category(category) if category.present?

      if uses_items.any?
        items_list = uses_items.map do |item|
          "- #{item.name} (#{item.slug})\n" \
          "  Category: #{item.category}\n" \
          "  URL: #{item.url || 'N/A'}\n" \
          "  Position: #{item.position}\n" \
          "  Published: #{item.published}\n" \
          "  Discontinued: #{item.discontinued}"
        end.join("\n\n")

        MCP::Tool::Response.new([ {
          type: "text",
          text: "Found #{uses_items.count} uses item(s):\n\n#{items_list}"
        } ])
      else
        MCP::Tool::Response.new([ {
          type: "text",
          text: "No uses items found with the specified criteria."
        } ])
      end
    rescue => e
      MCP::Tool::Response.new([ {
        type: "text",
        text: "Error listing uses items: #{e.message}"
      } ])
    end
  end
end
