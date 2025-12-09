# frozen_string_literal: true

class SlideServer
  def self.create
    MCP::Server.new(
      name: "spotlight-rails",
      version: "1.2.0",
      tools: [
        Tools::CreateSlideTool,
        Tools::UpdateSlideTool,
        Tools::FindSlideTool,
        Tools::ListSlidesTool
      ],
      server_context: {}
    )
  end
end
