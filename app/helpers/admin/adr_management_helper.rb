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
      link_adr_display_numbers(markdown.render(text)).html_safe
    end

    # HTML 中の解決可能な ADR 番号表記を該当 ADR の詳細ページへのリンクに
    # 変換する。markdown 描画は filter_html 有効のため、描画前のテキストに
    # HTML を注入せず、描画後の HTML のテキストノードだけを書き換える。
    # コードブロック・既存リンク内の表記は変換しない
    def link_adr_display_numbers(html)
      fragment = Nokogiri::HTML::DocumentFragment.parse(html)
      text_nodes = fragment.xpath(
        ".//text()[not(ancestor::a) and not(ancestor::code) and not(ancestor::pre)]"
      )
      return html if text_nodes.empty?

      references = ::AdrManagement::Adr.resolve_text_references(
        *text_nodes.map(&:content)
      )[:references]
      return html if references.empty?

      text_nodes.each do |node|
        content = node.content
        next unless content.match?(::AdrManagement::Adr::DISPLAY_NUMBER_TOKEN)

        # トークンは英数字とハイフンのみで構成されるため、先に全体を
        # エスケープしてもトークンの境界・内容は変化しない
        replaced = false
        linked = ERB::Util.html_escape(content).gsub(::AdrManagement::Adr::DISPLAY_NUMBER_TOKEN) do |token|
          adr = references[token]
          if adr
            replaced = true
            link_to(token, admin_adr_management_adr_path(adr), class: "text-indigo-600 hover:text-indigo-900 underline")
          else
            token
          end
        end
        node.replace(Nokogiri::HTML::DocumentFragment.parse(linked)) if replaced
      end
      fragment.to_html
    end
  end
end
