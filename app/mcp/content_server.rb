# frozen_string_literal: true

class ContentServer
  def self.create
    MCP::Server.new(
      name: "spotlight-rails",
      version: "1.4.0",
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
        Tools::ListProjectsTool,
        # UsesItem tools
        Tools::CreateUsesItemTool,
        Tools::UpdateUsesItemTool,
        Tools::FindUsesItemTool,
        Tools::ListUsesItemsTool
      ],
      server_context: {}
    )
  end
end
