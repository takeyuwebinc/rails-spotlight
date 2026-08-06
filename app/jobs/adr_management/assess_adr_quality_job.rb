# frozen_string_literal: true

module AdrManagement
  # ADR の登録・本文更新を契機に LLM 品質評価を実行する。
  # 評価は参考情報のため、対象 ADR が削除済みなら何もしない
  class AssessAdrQualityJob < ApplicationJob
    queue_as :default

    ORIGIN = "system:quality-assessment"

    def perform(adr_id)
      adr = Adr.find_by(id: adr_id)
      return unless adr

      AssessAdrQuality.perform(adr: adr, origin: ORIGIN)
    end
  end
end
