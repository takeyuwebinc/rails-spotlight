# frozen_string_literal: true

class ArticleServer
  def self.create
    MCP::Server.new(
      name: "spotlight-rails",
      version: "1.2.0",
      tools: [
        Tools::CreateArticleTool,
        Tools::UpdateArticleTool,
        Tools::FindArticleTool,
        Tools::CreateSlideTool,
        Tools::UpdateSlideTool,
        Tools::FindSlideTool,
        Tools::ListSlidesTool
      ],
      server_context: {}
    )
  end
end
