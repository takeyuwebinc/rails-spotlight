# frozen_string_literal: true

module AdrManagement
  # 検索品質の月次自動実行（recurring.yml でスケジュール）。
  # 評価（recall 測定）→評価履歴の保存→数値条件の自動点検→レポートの
  # GitHub Issue 化までを一連で行い、手動運用への依存で点検が実施されない
  # 状態を防ぐ。Issue 作成の失敗（トークン未設定・API エラー）は例外の
  # ままにしてエラー監視（Sentry）で検知する。評価の失敗（埋め込み API
  # 不通）はレポートに明記して縮退継続する。
  class SearchQualityReportJob < ApplicationJob
    queue_as :default

    REPO = "takeyuwebinc/rails-spotlight"
    LABEL = "search-quality"
    # 自動点検の対象は「検索評価基盤の3段構成」を定めた自案件のメタ ADR。
    # 数値の再評価条件を持つのはこの ADR のみで、判定は
    # CheckSearchQualityConditions が担う
    TARGET_ENGAGEMENT_CODE = "spotlight-rails"
    TARGET_ADR_NUMBER = 38
    ORIGIN = "system:search-quality-report"

    def perform
      previous_evaluation = SearchEvaluation.recent_first.first
      evaluation = run_evaluation
      check = CheckSearchQualityConditions.perform(
        evaluation: evaluation, previous_evaluation: previous_evaluation
      ).data
      record_auto_check(check)

      report = BuildSearchQualityReport.perform(
        since: 1.month.ago, evaluation: evaluation, check: check
      )
      Github::IssueClient.new.create_issue(
        repo: REPO,
        title: "ADR検索品質レポート #{Date.current.strftime("%Y-%m")}",
        body: report.data[:text],
        labels: [ LABEL ]
      )
    end

    private

    # 評価が失敗・空でもレポート発行は続ける（nil を返して縮退）
    def run_evaluation
      result = EvaluateGoldenQueries.perform
      if result.failure?
        Rails.error.report(
          RuntimeError.new("golden query evaluation failed: #{result.errors.map(&:message).join(", ")}"),
          handled: true
        )
        return nil
      end
      return nil if result.data[:recall].nil?

      SearchEvaluation.create!(
        k: result.data[:k],
        recall: result.data[:recall],
        details: result.data[:details],
        origin: ORIGIN
      )
    end

    # 対象 ADR が存在しない環境（開発・テスト）では点検を記録しない。
    # 記録の失敗はレポート発行を妨げない
    def record_auto_check(check)
      engagement = Engagement.where("LOWER(code) = ?", TARGET_ENGAGEMENT_CODE).first
      adr = engagement&.adrs&.find_by(number: TARGET_ADR_NUMBER)
      return unless adr

      outcome = RecordReevaluationCheck.perform(
        adr: adr,
        attributes: { result: check[:result], note: check[:note] },
        origin: ORIGIN
      )
      return unless outcome.failure?

      Rails.error.report(
        RuntimeError.new("auto reevaluation check failed: #{outcome.errors.map(&:message).join(", ")}"),
        handled: true
      )
    end
  end
end
