# frozen_string_literal: true

module AdrManagement
  # 検索品質レポート（検索実行数・0件率・取り逃がし報告・評価結果・自動点検・
  # レビュー待ち）の本文を組み立てる。rake タスク（手動確認）と月次ジョブ
  # （Issue 報告）が同じ集計・本文を使うための共通化。片方だけ数値の定義が
  # 変わる二重実装を防ぐ。
  class BuildSearchQualityReport < ApplicationAction
    ADMIN_HOST = "takeyuweb.co.jp"

    # evaluation / check は月次ジョブが実行結果を渡す。nil の場合（rake の
    # 集計のみ実行や評価失敗時）は該当セクションを縮退表示する
    def initialize(since:, evaluation: nil, check: nil)
      @since = since
      @evaluation = evaluation
      @check = check
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
      lines.concat(stats_section(summary, miss_reports))
      lines << ""
      lines.concat(evaluation_section)
      lines.concat(check_section)
      lines.concat(review_queue_section)
      lines << ""
      lines.concat(judgment_guide)
      lines.join("\n")
    end

    def stats_section(summary, miss_reports)
      lines = [ "- 検索実行数: #{summary[:total]} 件" ]
      summary[:by_mode].each { |mode, count| lines << "  - #{mode}: #{count} 件" }
      lines << "- 0件検索: #{summary[:zero_result_count]} 件#{zero_rate_label(summary)}"
      lines << "- 取り逃がし報告: #{miss_reports.size} 件"
      miss_reports.each do |report|
        target = report.adr ? report.adr.display_number : "(未到達)"
        lines << "  - #{report.created_at.to_date} #{target}: #{report.query}"
      end
      lines
    end

    def evaluation_section
      unless @evaluation
        return [ "- ゴールデンクエリ評価: 未実行（埋め込み API 障害またはゴールデンクエリ未登録）" ]
      end

      lines = [ format("- recall@%d: %.3f（ゴールデンクエリ評価）", @evaluation.k, @evaluation.recall) ]
      Array(@evaluation.details).each do |detail|
        missed = detail["missed"] || detail[:missed] || []
        next if missed.empty?

        query = detail["query"] || detail[:query]
        lines << "  - miss: #{query}（期待 ADR id: #{missed.join(", ")}）"
      end
      lines
    end

    def check_section
      return [] unless @check

      [ "- 自動点検（SPOTLIGHT-RAILS-38）: #{@check[:result]}" ]
    end

    def review_queue_section
      pending_logs = SearchLog.pending_review.count
      pending_reports = SearchMissReport.pending_review.count
      [
        "- レビュー待ち: 0件検索 #{pending_logs} 件 / 取り逃がし報告 #{pending_reports} 件",
        "  - 管理画面で処理: https://#{ADMIN_HOST}/admin/adr/search_quality"
      ]
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
        "- 数値条件（報告月3件以上・3ヶ月ゼロ件・ログ10万件・recall 低下）は自動点検済み。" \
        "suspected の場合は管理画面とこのレポートの内訳を確認し、対応（方式見直しの起票等）を判断する",
        "- レビュー待ちの0件検索・取り逃がし報告は管理画面のアクションで処理する",
        "- SPOTLIGHT-RAILS-27 の非数値条件（さくらのAI Engine の料金・約款の変更）は自動点検の対象外。" \
        "record_reevaluation_check_tool で手動点検する"
      ]
    end
  end
end
