# frozen_string_literal: true

module Tools
  class FindAdrEngagementTool < MCP::Tool
    extend AdrManagementToolSupport

    description "Find an ADR management engagement by code or name"

    input_schema(
      properties: {
        query: {
          type: "string",
          description: "Search keyword (code or name)"
        }
      },
      required: [ "query" ]
    )

    def self.call(query:, server_context:)
      engagement = AdrManagement::Engagement.find_by(code: query) ||
        AdrManagement::Engagement.where("code LIKE ?", "#{query}%").first ||
        AdrManagement::Engagement.where("name LIKE ?", "%#{query}%").first

      unless engagement
        return text_response(
          "Engagement not found for query: #{query}\n" \
          "list_adr_engagements_tool で表記揺れがないか確認し、存在しなければ " \
          "create_adr_engagement_tool で作成してください。"
        )
      end

      projects = engagement.projects.order(:start_date)
      projects_list = if projects.any?
        projects.map { |project| "  - #{project.name} (#{project.start_date}〜#{project.end_date})" }.join("\n")
      else
        "  (no projects)"
      end

      text_response(
        "Found engagement:\n" \
        "- Code: #{engagement.code}\n" \
        "- Name: #{engagement.name}\n" \
        "- Client: #{engagement.client.name}\n" \
        "- Description: #{engagement.description.presence || '(none)'}\n" \
        "- ADRs: #{engagement.adrs.count}\n" \
        "- Projects:\n#{projects_list}"
      )
    rescue => e
      text_response("Error finding engagement: #{e.message}")
    end
  end
end
