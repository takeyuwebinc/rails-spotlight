# frozen_string_literal: true

module Admin
  module AdrManagement
    # 取り逃がし報告レビューキューの「ゴールデンクエリとして採用」アクション。
    # 期待 ADR は報告の到達 ADR を使う（到達 ADR のない報告は期待を
    # 定められないため採用不可）。クエリ文言はキーワードのままでは
    # 自然言語評価に不適なことがあるため、編集して採用できる
    class SearchMissReportGoldenQueriesController < Admin::BaseController
      def create
        report = ::AdrManagement::SearchMissReport.find(params[:search_miss_report_id])
        if report.adr.nil?
          return redirect_to admin_adr_management_search_quality_path,
            alert: "到達 ADR のない報告はゴールデンクエリとして採用できません。"
        end

        ::AdrManagement::GoldenQuery.create!(
          adr: report.adr,
          query: params[:query].presence || report.query,
          note: "取り逃がし報告（#{report.created_at.to_date}）由来",
          origin: "admin:#{current_admin_email}"
        )
        report.update!(reviewed_at: Time.current)
        redirect_to admin_adr_management_search_quality_path, notice: "ゴールデンクエリとして採用しました。"
      end
    end
  end
end
