# frozen_string_literal: true

module Admin
  module AdrManagement
    # 品質所見レビューキューの所見単位の処理アクション。
    # 人が選べるのは addressed（修正した）と dismissed（誤検知として却下）のみ。
    # obsolete は失効・再評価による自動クローズ専用で、人の操作では記録しない
    class QualityFindingReviewsController < Admin::BaseController
      HUMAN_RESULTS = %w[addressed dismissed].freeze

      def create
        assessment = ::AdrManagement::QualityAssessment.find(params[:quality_assessment_id])
        result = params[:review_result].to_s
        unless HUMAN_RESULTS.include?(result)
          return redirect_to admin_adr_management_quality_path, alert: "処理結果の指定が不正です。"
        end

        assessment.resolve_finding!(params[:code].to_s, result: result)
        notice = result == "addressed" ? "所見を「修正した」として処理しました。" : "所見を誤検知として却下しました。"
        redirect_to admin_adr_management_quality_path, notice: notice
      end
    end
  end
end
