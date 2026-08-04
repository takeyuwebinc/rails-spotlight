# frozen_string_literal: true

module AdrManagement
  # 検索評価基盤の再評価条件（数値で判定可能なもの）を機械判定する。
  # 閾値は「検索評価基盤の3段構成」の決定（SPOTLIGHT-RAILS-38）で定めた
  # 再評価条件と対応しており、条件を変えるときは ADR の置換とあわせて見直す。
  # 判定結果は点検記録（no_trigger / suspected）として自動登録される想定で、
  # note に計測値を含めて根拠を残す。
  class CheckSearchQualityConditions < ApplicationAction
    # 月間の取り逃がし報告がこの件数以上なら、検索方式の見直し検討に該当
    MISS_REPORTS_PER_MONTH_THRESHOLD = 3
    # 報告経路の機能不全を疑うまでの無報告観測期間
    ZERO_REPORT_OBSERVATION = 3.months
    # 検索ログの保持方式（ローテーション）を検討し始める件数
    SEARCH_LOG_COUNT_THRESHOLD = 100_000

    def initialize(evaluation: nil, previous_evaluation: nil)
      @evaluation = evaluation
      @previous_evaluation = previous_evaluation
    end

    def perform
      findings = []
      findings << check_monthly_miss_reports
      findings << check_silent_report_channel
      findings << check_log_volume
      findings << check_recall_drop
      findings.compact!

      success({
        result: findings.any? ? "suspected" : "no_trigger",
        note: build_note(findings)
      })
    end

    private

    def check_monthly_miss_reports
      count = SearchMissReport.where(created_at: 1.month.ago..).count
      return nil if count < MISS_REPORTS_PER_MONTH_THRESHOLD

      "取り逃がし報告が月#{MISS_REPORTS_PER_MONTH_THRESHOLD}件以上（直近1ヶ月 #{count} 件）。" \
      "ハイブリッド再ランク等への切替検討の起票が必要"
    end

    # 報告ゼロは「取り逃がしがない」と「報告経路が機能していない」を区別できない。
    # 観測期間ぶんの検索実績があるのに報告が皆無なら後者を疑う
    def check_silent_report_channel
      oldest_log = SearchLog.minimum(:created_at)
      return nil if oldest_log.nil? || oldest_log > ZERO_REPORT_OBSERVATION.ago

      searches = SearchLog.where(created_at: ZERO_REPORT_OBSERVATION.ago..).count
      reports = SearchMissReport.where(created_at: ZERO_REPORT_OBSERVATION.ago..).count
      return nil unless searches.positive? && reports.zero?

      "直近3ヶ月の検索 #{searches} 件に対し取り逃がし報告が0件。報告経路（Skill 手順・ツール設計）の見直しが必要"
    end

    def check_log_volume
      count = SearchLog.count
      return nil if count <= SEARCH_LOG_COUNT_THRESHOLD

      "検索ログが#{SEARCH_LOG_COUNT_THRESHOLD}件を超過（#{count} 件）。保持期間・ローテーションの検討が必要"
    end

    def check_recall_drop
      return nil unless @evaluation && @previous_evaluation
      return nil if @evaluation.recall >= @previous_evaluation.recall

      format(
        "recall@%d が前回から低下（%.3f → %.3f）。直近の検索実装変更・コーパス変化の確認が必要",
        @evaluation.k, @previous_evaluation.recall, @evaluation.recall
      )
    end

    def build_note(findings)
      measurements = [
        "自動点検（月次ジョブ）。計測値: 直近1ヶ月の取り逃がし報告 #{SearchMissReport.where(created_at: 1.month.ago..).count} 件、" \
        "検索ログ総数 #{SearchLog.count} 件" \
        "#{@evaluation ? format("、recall@%d %.3f", @evaluation.k, @evaluation.recall) : "、評価未実行"}" \
        "#{@previous_evaluation ? format("（前回 %.3f）", @previous_evaluation.recall) : ""}"
      ]
      measurements.concat(findings.map { |finding| "発火疑い: #{finding}" })
      measurements.join("\n")
    end
  end
end
