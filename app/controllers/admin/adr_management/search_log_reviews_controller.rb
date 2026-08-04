# frozen_string_literal: true

module Admin
  module AdrManagement
    # 0件検索レビューキューの「問題なし」アクション
    class SearchLogReviewsController < Admin::BaseController
      def create
        log = ::AdrManagement::SearchLog.find(params[:search_log_id])
        log.update!(reviewed_at: Time.current)
        redirect_to admin_adr_management_search_quality_path, notice: "0件検索を問題なしとして処理しました。"
      end
    end
  end
end
