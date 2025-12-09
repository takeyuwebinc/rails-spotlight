# frozen_string_literal: true

class ContentServer
  def self.create
    MCP::Server.new(
      name: "spotlight-rails",
      version: "1.3.0",
      tools: [
        # Slide tools
        Tools::CreateSlideTool,
        Tools::UpdateSlideTool,
        Tools::FindSlideTool,
        Tools::ListSlidesTool,
        # Project tools
        Tools::CreateProjectTool,
        Tools::UpdateProjectTool,
        Tools::FindProjectTool,
        Tools::ListProjectsTool
      ],
      server_context: {}
    )
  end
end
