# frozen_string_literal: true

module Tools
  class FindAdrProjectTool < MCP::Tool
    extend AdrManagementToolSupport

    description "Find an ADR management project by name within an engagement"

    input_schema(
      properties: {
        engagement_code: {
          type: "string",
          description: "Code of the engagement"
        },
        query: {
          type: "string",
          description: "Search keyword (project name, partial match)"
        }
      },
      required: [ "engagement_code", "query" ]
    )

    def self.call(engagement_code:, query:, server_context:)
      engagement = find_engagement_or_error(engagement_code)
      return engagement if engagement.is_a?(MCP::Tool::Response)

      project = engagement.projects.find_by(name: query) ||
        engagement.projects.where("name LIKE ?", "%#{query}%").first

      unless project
        return text_response(
          "Project not found for query: #{query} (engagement: #{engagement.code})\n" \
          "list_adr_projects_tool で一覧を確認し、存在しなければ create_adr_project_tool で作成してください。"
        )
      end

      text_response(
        "Found project:\n" \
        "- Name: #{project.name}\n" \
        "- Engagement: #{engagement.code}\n" \
        "- Period: #{project.start_date}〜#{project.end_date}\n" \
        "- ADRs: #{project.adrs.count}"
      )
    rescue => e
      text_response("Error finding project: #{e.message}")
    end
  end
end
