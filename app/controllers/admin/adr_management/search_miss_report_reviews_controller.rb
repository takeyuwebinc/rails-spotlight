# frozen_string_literal: true

module Admin
  module AdrManagement
    # 取り逃がし報告レビューキューの「対応済みにする」アクション
    class SearchMissReportReviewsController < Admin::BaseController
      def create
        report = ::AdrManagement::SearchMissReport.find(params[:search_miss_report_id])
        report.update!(reviewed_at: Time.current)
        redirect_to admin_adr_management_search_quality_path, notice: "取り逃がし報告を対応済みにしました。"
      end
    end
  end
end
