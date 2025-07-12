# frozen_string_literal: true

class ArticleServer
  def self.create
    MCP::Server.new(
      name: "spotlight-rails-articles",
      version: "1.0.0",
      tools: [
        Tools::CreateArticleTool,
        Tools::UpdateArticleTool,
        Tools::FindArticleTool
      ],
      server_context: {}
    )
  end
end
