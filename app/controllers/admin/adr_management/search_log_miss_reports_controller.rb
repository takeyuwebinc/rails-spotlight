# frozen_string_literal: true

module Admin
  module AdrManagement
    # 0件検索レビューキューの「取り逃がしとして記録」アクション。
    # 記録ルール（必須項目等）は MCP ツールと同じ Action に委譲する
    class SearchLogMissReportsController < Admin::BaseController
      def create
        log = ::AdrManagement::SearchLog.find(params[:search_log_id])
        adr, error = resolve_adr
        return redirect_to admin_adr_management_search_quality_path, alert: error if error

        outcome = ::AdrManagement::ReportSearchMiss.perform(
          query: log.query.presence || log.keyword.to_s,
          note: params[:note],
          adr: adr,
          origin: "admin:#{current_admin_email}"
        )
        if outcome.failure?
          return redirect_to admin_adr_management_search_quality_path,
            alert: outcome.errors.map(&:message).join(" / ")
        end

        log.update!(reviewed_at: Time.current)
        redirect_to admin_adr_management_search_quality_path, notice: "取り逃がしとして記録しました。"
      end

      private

      # 到達 ADR は任意。指定する場合は案件 code と番号の両方が必要
      def resolve_adr
        code = params[:engagement_code].to_s.strip
        number = params[:number].to_s.strip
        return [ nil, nil ] if code.blank? && number.blank?
        return [ nil, "到達 ADR を指定する場合は案件 code と番号を両方入力してください。" ] if code.blank? || number.blank?

        engagement = ::AdrManagement::Engagement.where("LOWER(code) = ?", code.downcase).first
        adr = engagement&.adrs&.find_by(number: number)
        return [ nil, "ADR #{code.upcase}-#{number} が見つかりません。" ] unless adr

        [ adr, nil ]
      end
    end
  end
end
