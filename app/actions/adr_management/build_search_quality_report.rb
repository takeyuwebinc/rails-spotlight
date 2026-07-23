# frozen_string_literal: true

module AdrManagement
  # 検索品質レポート（検索実行数・0件率・取り逃がし報告）の本文を組み立てる。
  # rake タスク（手動確認）と月次ジョブ（Issue 報告）が同じ集計・本文を
  # 使うための共通化。片方だけ数値の定義が変わる二重実装を防ぐ。
  class BuildSearchQualityReport < ApplicationAction
    def initialize(since:)
      @since = since
    end

    def perform
      summary = SearchLog.summary(since: @since)
      miss_reports = SearchMissReport.where(created_at: @since..).recent_first.to_a
      success({
        text: build_text(summary, miss_reports),
        summary: summary,
        miss_report_count: miss_reports.size
      })
    end

    private

    def build_text(summary, miss_reports)
      lines = [ "対象期間: #{@since.to_date} 〜 #{Date.current}", "" ]
      lines << "- 検索実行数: #{summary[:total]} 件"
      summary[:by_mode].each { |mode, count| lines << "  - #{mode}: #{count} 件" }
      lines << "- 0件検索: #{summary[:zero_result_count]} 件#{zero_rate_label(summary)}"
      lines << "- 取り逃がし報告: #{miss_reports.size} 件"
      miss_reports.each do |report|
        target = report.adr ? report.adr.display_number : "(未到達)"
        lines << "  - #{report.created_at.to_date} #{target}: #{report.query}"
      end
      lines << ""
      lines.concat(judgment_guide)
      lines.join("\n")
    end

    def zero_rate_label(summary)
      return "" if summary[:total].zero?

      format("（%.1f%%）", summary[:zero_result_count].fdiv(summary[:total]) * 100)
    end

    # レポートの読み手（管理者・Coding Agent）が数値から次の行動を
    # 判断できるよう、再評価条件の目安を本文に含める
    def judgment_guide
      [
        "判断の目安（SPOTLIGHT-RAILS-38 の再評価条件）:",
        "- 取り逃がし報告が月3件以上 → SPOTLIGHT-RAILS-27 の再評価条件「取り逃がしの頻発」に該当。" \
        "ハイブリッド再ランク等への切替検討を起票する",
        "- 報告が3ヶ月以上ゼロ件かつ検索実行あり → 報告経路が機能していない疑い。配布 Skill の手順を見直す",
        "- 確認結果は record_reevaluation_check_tool で SPOTLIGHT-RAILS-38・27 の点検として記録する"
      ]
    end
  end
end
