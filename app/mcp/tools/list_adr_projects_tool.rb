# frozen_string_literal: true

module Tools
  class ListAdrProjectsTool < MCP::Tool
    extend AdrManagementToolSupport

    description "List ADR management projects (period-bound development units) of an engagement"

    input_schema(
      properties: {
        engagement_code: {
          type: "string",
          description: "Code of the engagement"
        }
      },
      required: [ "engagement_code" ]
    )

    def self.call(engagement_code:, server_context:)
      engagement = find_engagement_or_error(engagement_code)
      return engagement if engagement.is_a?(MCP::Tool::Response)

      projects = engagement.projects.order(:start_date)

      if projects.any?
        list = projects.map do |project|
          "- #{project.name} (#{project.start_date}〜#{project.end_date})"
        end.join("\n")
        text_response("Found #{projects.size} project(s) in #{engagement.code}:\n#{list}")
      else
        text_response("No projects found in engagement #{engagement.code}. create_adr_project_tool で作成できます。")
      end
    rescue => e
      text_response("Error listing projects: #{e.message}")
    end
  end
end
