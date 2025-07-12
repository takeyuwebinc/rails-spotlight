# frozen_string_literal: true

module Tools
  class FindArticleTool < MCP::Tool
    description "Find an article by slug and return its details"

    input_schema(
      properties: {
        slug: {
          type: "string",
          description: "The slug of the article to find"
        }
      },
      required: [ "slug" ]
    )

    def self.call(slug:, server_context:)
      article = Article.find_by(slug: slug)

      if article
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Article found:\n" \
                "- Title: #{article.title}\n" \
                "- Slug: #{article.slug}\n" \
                "- Description: #{article.description}\n" \
                "- Published at: #{article.published_at}\n" \
                "- Tags: #{article.tags.pluck(:name).join(', ')}\n" \
                "- Created at: #{article.created_at}\n" \
                "- Updated at: #{article.updated_at}"
        } ])
      else
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Article not found with slug: #{slug}"
        } ])
      end
    rescue => e
      MCP::Tool::Response.new([ {
        type: "text",
        text: "Error finding article: #{e.message}"
      } ])
    end
  end
end
