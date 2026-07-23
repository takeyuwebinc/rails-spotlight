# frozen_string_literal: true

module Tools
  class ReportSearchMissTool < MCP::Tool
    extend AdrManagementToolSupport

    description "Report a search miss: a relevant ADR existed but search_adrs failed to surface it. " \
                "Report ONLY when you actually detected the miss (e.g. the natural language search " \
                "missed an ADR you later reached via keyword search, listing, or prior knowledge). " \
                "Do not rate ordinary search results. Specify the reached ADR with engagement_code " \
                "and number when known; omit both if you could not reach the ADR at all. " \
                "Reports are the evidence for reviewing the search implementation."

    input_schema(
      properties: {
        query: {
          type: "string",
          description: "The search query that failed to surface the ADR"
        },
        note: {
          type: "string",
          description: "How the ADR was reached instead (or why you believe a relevant ADR exists)"
        },
        engagement_code: {
          type: "string",
          description: "Code of the engagement of the reached ADR (specify together with number)"
        },
        number: {
          type: "integer",
          description: "Number of the reached ADR within the engagement (specify together with engagement_code)"
        }
      },
      required: [ "query", "note" ]
    )

    def self.call(query:, note:, engagement_code: nil, number: nil, server_context:)
      adr, error = resolve_adr(engagement_code, number)
      return error if error

      outcome = AdrManagement::ReportSearchMiss.perform(
        query: query, note: note, adr: adr, origin: origin_from(server_context)
      )
      return error_response(outcome.errors) if outcome.failure?

      report = outcome.data
      lines = [
        "Search miss reported:",
        "- Query: #{report.query}",
        "- Reached ADR: #{report.adr ? report.adr.display_number : "(none)"}",
        "- Note: #{report.note}"
      ]
      text_response(lines.join("\n"))
    rescue => e
      text_response("Error reporting search miss: #{e.message}")
    end

    # engagement_code と number は到達 ADR の指定として対で扱う。
    # 片方だけの指定はどの ADR か特定できないため入力エラーにする
    def self.resolve_adr(engagement_code, number)
      return [ nil, nil ] if engagement_code.blank? && number.nil?

      if engagement_code.blank? || number.nil?
        return [ nil, error_response(AdrManagement::OperationError.build(
          kind: :invalid_input,
          param: engagement_code.blank? ? "engagement_code" : "number",
          message: "到達した ADR を指定する場合は engagement_code と number を両方指定してください",
          next_action: "両方を指定するか、到達 ADR が特定できない場合は両方を省略してください"
        )) ]
      end

      engagement = find_engagement_or_error(engagement_code)
      return [ nil, engagement ] if engagement.is_a?(MCP::Tool::Response)

      adr = engagement.adrs.find_by(number: number)
      unless adr
        return [ nil, error_response(AdrManagement::OperationError.build(
          kind: :master_not_found,
          param: "number",
          message: "ADR #{adr_number_label(engagement, number)} が存在しません",
          next_action: "search_adrs_tool で対象案件の ADR 番号を確認してください"
        )) ]
      end

      [ adr, nil ]
    end
  end
end
