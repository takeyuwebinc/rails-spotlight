# frozen_string_literal: true

class ContentServer
  # origin: このリクエストの更新経路（どの認証主体からの操作か）。
  # ADR の版履歴などの記録処理が server_context 経由で参照する。
  def self.create(origin: nil)
    MCP::Server.new(
      name: "spotlight-rails",
      version: "1.6.0",
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
        Tools::CreateWorkHourEntryTool,
        # ADR management master tools
        Tools::ListAdrClientsTool,
        Tools::FindAdrClientTool,
        Tools::CreateAdrClientTool,
        Tools::ListAdrEngagementsTool,
        Tools::FindAdrEngagementTool,
        Tools::CreateAdrEngagementTool,
        Tools::ListAdrProjectsTool,
        Tools::FindAdrProjectTool,
        Tools::CreateAdrProjectTool,
        # ADR tools
        Tools::SearchAdrsTool,
        Tools::GetAdrTool,
        Tools::RegisterAdrTool,
        Tools::UpdateAdrTool,
        Tools::RecordReevaluationCheckTool
      ],
      server_context: { origin: origin }
    )
  end
end
