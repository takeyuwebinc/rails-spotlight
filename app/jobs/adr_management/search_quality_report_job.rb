# frozen_string_literal: true

module AdrManagement
  # 検索品質レポートを月次で GitHub Issue として報告する（recurring.yml で
  # スケジュール実行）。検索評価の月次確認が手動実行への依存で実施されない
  # 状態を防ぐ。失敗（トークン未設定・API エラー）は例外のままにして
  # エラー監視（Sentry）で検知する。
  class SearchQualityReportJob < ApplicationJob
    queue_as :default

    REPO = "takeyuwebinc/rails-spotlight"
    LABEL = "search-quality"

    def perform
      report = BuildSearchQualityReport.perform(since: 1.month.ago)
      Github::IssueClient.new.create_issue(
        repo: REPO,
        title: "ADR検索 品質レポート #{Date.current.strftime("%Y-%m")}",
        body: report.data[:text],
        labels: [ LABEL ]
      )
    end
  end
end
