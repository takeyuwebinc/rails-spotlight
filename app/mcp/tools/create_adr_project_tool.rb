# frozen_string_literal: true

module Tools
  class CreateAdrProjectTool < MCP::Tool
    extend AdrManagementToolSupport

    description "Create an ADR management project (period-bound development unit) under an engagement"

    input_schema(
      properties: {
        engagement_code: {
          type: "string",
          description: "Code of the engagement this project belongs to"
        },
        name: {
          type: "string",
          description: "Project name (e.g. Fabble保守開発2026年度)"
        },
        start_date: {
          type: "string",
          description: "Period start date (YYYY-MM-DD)"
        },
        end_date: {
          type: "string",
          description: "Period end date (YYYY-MM-DD)"
        }
      },
      required: [ "engagement_code", "name" ]
    )

    def self.call(engagement_code:, name:, start_date: nil, end_date: nil, server_context:)
      engagement = find_engagement_or_error(engagement_code)
      return engagement if engagement.is_a?(MCP::Tool::Response)

      parsed_start, error = parse_date_or_error(start_date, "start_date")
      return error if error
      parsed_end, error = parse_date_or_error(end_date, "end_date")
      return error if error

      project = engagement.projects.new(name: name, start_date: parsed_start, end_date: parsed_end)

      if project.save
        text_response(
          "Project created successfully:\n" \
          "- Name: #{project.name}\n" \
          "- Engagement: #{engagement.code}\n" \
          "- Period: #{project.start_date}〜#{project.end_date}"
        )
      else
        error_response(project.errors.map do |error|
          AdrManagement::OperationError.build(
            kind: :invalid_input,
            param: error.attribute.to_s,
            message: error.full_message,
            next_action: "入力内容を修正して再実行してください"
          )
        end)
      end
    rescue => e
      text_response("Error creating project: #{e.message}")
    end
  end
end
