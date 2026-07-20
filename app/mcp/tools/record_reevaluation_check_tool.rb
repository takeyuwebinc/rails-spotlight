# frozen_string_literal: true

module Tools
  class RecordReevaluationCheckTool < MCP::Tool
    extend AdrManagementToolSupport

    description "Record a reevaluation check for an accepted ADR: whether its reevaluation " \
                "conditions are still unmet (no_trigger) or appear to be met (suspected). " \
                "Record suspected immediately when you observe a condition-related event " \
                "(with what you observed in note); record no_trigger during periodic review. " \
                "Only accepted ADRs that have reevaluation conditions can be checked."

    input_schema(
      properties: {
        engagement_code: {
          type: "string",
          description: "Code of the engagement the ADR belongs to"
        },
        number: {
          type: "integer",
          description: "ADR number within the engagement"
        },
        result: {
          type: "string",
          enum: AdrManagement::ReevaluationCheck::RESULTS,
          description: "no_trigger: conditions not met / suspected: conditions appear to be met"
        },
        note: {
          type: "string",
          description: "Observation memo. Required for suspected (what was observed)"
        },
        checked_on: {
          type: "string",
          description: "Check date (YYYY-MM-DD, default: today. Future dates are rejected)"
        }
      },
      required: [ "engagement_code", "number", "result" ]
    )

    def self.call(engagement_code:, number:, result:, note: nil, checked_on: nil, server_context:)
      engagement = find_engagement_or_error(engagement_code)
      return engagement if engagement.is_a?(MCP::Tool::Response)

      adr = engagement.adrs.find_by(number: number)
      unless adr
        return error_response(AdrManagement::OperationError.build(
          kind: :master_not_found,
          param: "number",
          message: "ADR #{adr_number_label(engagement, number)} が存在しません",
          next_action: "search_adrs_tool で対象案件の ADR 番号を確認してください"
        ))
      end

      checked_date, error = parse_date_or_error(checked_on, "checked_on")
      return error if error

      outcome = AdrManagement::RecordReevaluationCheck.perform(
        adr: adr,
        attributes: { result: result, note: note, checked_on: checked_date },
        origin: origin_from(server_context)
      )
      return error_response(outcome.errors) if outcome.failure?

      check = outcome.data
      lines = [
        "Reevaluation check recorded for #{adr.display_number}:",
        "- Checked on: #{check.checked_on}",
        "- Result: #{check.result}"
      ]
      lines << "- Note: #{check.note}" if check.note.present?
      if check.suspected?
        lines << "発火疑いを記録しました。決定の見直しが必要なら、置換指定付きの登録" \
                 "（register_adr_tool の superseded_numbers）で新しい決定を起票してください。"
      end
      text_response(lines.join("\n"))
    rescue => e
      text_response("Error recording reevaluation check: #{e.message}")
    end
  end
end
