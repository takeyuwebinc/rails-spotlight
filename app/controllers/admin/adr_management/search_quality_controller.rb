# frozen_string_literal: true

module Admin
  module AdrManagement
    class SearchQualityController < Admin::BaseController
      def show
        @summary = ::AdrManagement::SearchLog.summary(since: 30.days.ago)
        @miss_report_count = ::AdrManagement::SearchMissReport.where(created_at: 30.days.ago..).count
        @pending_logs = ::AdrManagement::SearchLog.pending_review.recent_first
        @pending_reports = ::AdrManagement::SearchMissReport.pending_review
          .includes(adr: :engagement).recent_first
        @evaluations = ::AdrManagement::SearchEvaluation.recent_first.limit(12)
        @golden_queries = ::AdrManagement::GoldenQuery.includes(adr: :engagement).recent_first
      end
    end
  end
end
