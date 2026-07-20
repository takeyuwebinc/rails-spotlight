# frozen_string_literal: true

module Admin
  module AdrManagementHelper
    ADR_STATUS_LABELS = {
      "proposed" => "提案中",
      "accepted" => "承認済み",
      "rejected" => "却下",
      "deprecated" => "廃止",
      "superseded" => "置換"
    }.freeze

    ADR_CONFIDENCE_LABELS = {
      "high" => "高",
      "medium" => "中",
      "low" => "低"
    }.freeze

    ADR_CHANGE_TYPE_LABELS = {
      "created" => "作成",
      "updated" => "更新",
      "status_changed" => "ステータス変更（置換）",
      "engagement_changed" => "案件変更"
    }.freeze

    def adr_status_label(status)
      ADR_STATUS_LABELS.fetch(status, status)
    end

    def adr_confidence_label(confidence)
      ADR_CONFIDENCE_LABELS.fetch(confidence, confidence)
    end

    def adr_change_type_label(change_type)
      ADR_CHANGE_TYPE_LABELS.fetch(change_type, change_type)
    end

    def render_adr_markdown(text)
      return "" if text.blank?

      renderer = Redcarpet::Render::HTML.new(
        filter_html: true, hard_wrap: true,
        link_attributes: { rel: "noopener", target: "_blank" }
      )
      markdown = Redcarpet::Markdown.new(
        renderer,
        tables: true, fenced_code_blocks: true, autolink: true, strikethrough: true
      )
      markdown.render(text).html_safe
    end
  end
end
