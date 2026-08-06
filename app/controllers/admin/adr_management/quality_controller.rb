# frozen_string_literal: true

module Admin
  module AdrManagement
    class QualityController < Admin::BaseController
      def show
        @summary = ::AdrManagement::QualityAssessment.findings_summary(since: 30.days.ago)
        @pending_assessments = ::AdrManagement::QualityAssessment.pending_review
          .includes(adr: :engagement).recent_first
      end
    end
  end
end
