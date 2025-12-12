# frozen_string_literal: true

class ContentServer
  def self.create
    MCP::Server.new(
      name: "spotlight-rails",
      version: "1.5.0",
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
        Tools::ListUsesItemsTool,
        # WorkHour Client tools
        Tools::ListWorkHourClientsTool,
        Tools::FindWorkHourClientTool,
        Tools::CreateWorkHourClientTool,
        # WorkHour Project tools
        Tools::ListWorkHourProjectsTool,
        Tools::FindWorkHourProjectTool,
        Tools::CreateWorkHourProjectTool,
        # WorkHour Estimate tools
        Tools::ListWorkHourEstimatesTool,
        Tools::CreateWorkHourEstimateTool,
        # WorkHour Entry tools
        Tools::ListWorkHourEntriesTool,
        Tools::CreateWorkHourEntryTool
      ],
      server_context: {}
    )
  end
end
