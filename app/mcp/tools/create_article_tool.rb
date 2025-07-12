# frozen_string_literal: true

module Tools
  class CreateArticleTool < MCP::Tool
    description "Create a new article from markdown content with YAML frontmatter"

    input_schema(
      properties: {
        content: {
          type: "string",
          description: "The markdown content with YAML frontmatter (including title, slug, description, published_date, tags, etc.)"
        }
      },
      required: [ "content" ]
    )

    def self.call(content:, server_context:)
      article = Article.import_from_markdown(content)

      if article
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Article created successfully:\n" \
                "- Title: #{article.title}\n" \
                "- Slug: #{article.slug}\n" \
                "- Published at: #{article.published_at}\n" \
                "- Tags: #{article.tags.pluck(:name).join(', ')}"
        } ])
      else
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Failed to create article. Please check the markdown content and ensure it has valid YAML frontmatter with required fields (title, slug, description, published_date)."
        } ])
      end
    rescue => e
      MCP::Tool::Response.new([ {
        type: "text",
        text: "Error creating article: #{e.message}"
      } ])
    end
  end
end
