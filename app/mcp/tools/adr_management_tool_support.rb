# frozen_string_literal: true

module Tools
  # ADR 管理系 MCP ツールの共通処理。エラー応答は Coding Agent が人間の
  # 介入なしに次の行動を判断できるよう、種別・原因パラメータ・推奨される
  # 次のアクションを含む形式に揃える。
  module AdrManagementToolSupport
    def text_response(text)
      MCP::Tool::Response.new([ { type: "text", text: text } ])
    end

    def error_response(errors)
      body = Array(errors).map { |error| format_error(error) }.join("\n\n")
      text_response(body)
    end

    def format_error(error)
      return "Error: #{error}" unless error.is_a?(AdrManagement::OperationError)

      lines = [ "Error: #{error.message}", "- 種別: #{error.kind}" ]
      lines << "- 原因パラメータ: #{error.param}" if error.param
      lines << "- 次のアクション: #{error.next_action}" if error.next_action
      lines.join("\n")
    end

    def origin_from(server_context)
      (server_context || {})[:origin].presence || "unknown"
    end

    def find_engagement_or_error(code)
      engagement = AdrManagement::Engagement.find_by(code: code)
      return engagement if engagement

      error_response(AdrManagement::OperationError.build(
        kind: :master_not_found,
        param: "engagement_code",
        message: "案件（code: #{code}）が存在しません",
        next_action: "list_adr_engagements_tool で表記揺れがないか確認し、" \
                     "存在しなければ create_adr_engagement_tool で案件を作成してください"
      ))
    end

    def adr_summary_line(adr, relevance: nil)
      parts = [
        "#{adr.engagement.code}-#{adr.number}",
        "[#{adr.status}/#{adr.confidence}]",
        adr.decided_on.to_s,
        adr.title
      ]
      parts << format("(関連度: %.3f)", relevance) if relevance
      "- #{parts.join(' ')}"
    end

    def parse_date_or_error(value, param)
      return [ nil, nil ] if value.blank?

      [ Date.parse(value), nil ]
    rescue ArgumentError, TypeError
      [ nil, error_response(AdrManagement::OperationError.build(
        kind: :invalid_input,
        param: param,
        message: "#{param} の日付形式が不正です: #{value}",
        next_action: "YYYY-MM-DD 形式で指定してください"
      )) ]
    end
  end
end
