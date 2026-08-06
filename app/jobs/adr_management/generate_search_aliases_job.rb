# frozen_string_literal: true

module AdrManagement
  # ADR の登録・本文更新を契機に検索エイリアスを生成する。
  # エイリアスは検索の補助情報のため、対象 ADR が削除済みなら何もしない
  class GenerateSearchAliasesJob < ApplicationJob
    queue_as :default

    def perform(adr_id)
      adr = Adr.find_by(id: adr_id)
      return unless adr

      GenerateSearchAliases.perform(adr: adr)
    end
  end
end
