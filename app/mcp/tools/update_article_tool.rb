# frozen_string_literal: true

module Tools
  class UpdateArticleTool < MCP::Tool
    description "Update an existing article by slug with new markdown content"

    input_schema(
      properties: {
        slug: {
          type: "string",
          description: "The slug of the article to update"
        },
        content: {
          type: "string",
          description: "The new markdown content with YAML frontmatter"
        }
      },
      required: [ "slug", "content" ]
    )

    def self.call(slug:, content:, server_context:)
      # Find the existing article
      article = Article.find_by(slug: slug)

      unless article
        return MCP::Tool::Response.new([ {
          type: "text",
          text: "Article not found with slug: #{slug}"
        } ])
      end

      # Update the article with new content
      updated_article = Article.import_from_markdown(content)

      if updated_article
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Article updated successfully:\n" \
                "- Title: #{updated_article.title}\n" \
                "- Slug: #{updated_article.slug}\n" \
                "- Published at: #{updated_article.published_at}\n" \
                "- Tags: #{updated_article.tags.pluck(:name).join(', ')}"
        } ])
      else
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Failed to update article. Please check the markdown content and ensure it has valid YAML frontmatter."
        } ])
      end
    rescue => e
      MCP::Tool::Response.new([ {
        type: "text",
        text: "Error updating article: #{e.message}"
      } ])
    end
  end
end
