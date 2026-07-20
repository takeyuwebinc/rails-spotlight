# frozen_string_literal: true

module Tools
  class GetAdrTool < MCP::Tool
    extend AdrManagementToolSupport

    description "Get the full text of an ADR, including its supersession chain (both directions) and revision summary"

    input_schema(
      properties: {
        engagement_code: {
          type: "string",
          description: "Code of the engagement the ADR belongs to"
        },
        number: {
          type: "integer",
          description: "ADR number within the engagement"
        }
      },
      required: [ "engagement_code", "number" ]
    )

    def self.call(engagement_code:, number:, server_context:)
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

      text_response(format_adr(adr))
    rescue => e
      text_response("Error getting ADR: #{e.message}")
    end

    def self.format_adr(adr)
      sections = [
        "# #{adr.display_number}: #{adr.title}",
        "- Status: #{adr.status}",
        "- Confidence: #{adr.confidence}",
        "- Decided on: #{adr.decided_on}",
        "- Project: #{adr.project&.name || '(none)'}",
        "",
        "## コンテキスト\n#{adr.context}",
        "## 決定\n#{adr.decision}",
        "## 結果\n#{adr.consequences}"
      ]
      sections << "## 代替案\n#{adr.alternatives}" if adr.alternatives.present?
      sections << "## 再評価条件\n#{adr.reevaluation_conditions}" if adr.reevaluation_conditions.present?
      sections << "## 参考資料\n#{adr.reference_links}" if adr.reference_links.present?
      sections << supersession_section(adr)
      sections << revisions_section(adr)
      sections.compact.join("\n\n")
    end

    def self.supersession_section(adr)
      lines = []
      if adr.superseded_adrs.any?
        lines << "この ADR が置き換えた決定:"
        adr.superseded_adrs.each { |old| lines << adr_summary_line(old) }
      end
      if (successor = adr.superseding_adr)
        lines << "この ADR を置き換えた決定（こちらが現行）:"
        lines << adr_summary_line(successor)
      end
      return nil if lines.empty?

      "## 置換変遷\n#{lines.join("\n")}"
    end

    def self.revisions_section(adr)
      revisions = adr.revisions.recent_first.limit(10)
      return nil if revisions.empty?

      lines = revisions.map do |revision|
        fields = revision.changed_fields.present? ? " fields=#{Array(revision.changed_fields).join(',')}" : ""
        "- #{revision.created_at.strftime('%Y-%m-%d %H:%M')} #{revision.change_type} (origin: #{revision.origin})#{fields}"
      end
      "## 版履歴（新しい順、最大10件）\n#{lines.join("\n")}"
    end
  end
end
