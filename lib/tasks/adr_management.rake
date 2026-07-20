# frozen_string_literal: true

namespace :adr_management do
  desc "全 ADR の検索インデックスを再構築する（埋め込みモデル切替・障害復旧用）"
  task rebuild_search_index: :environment do
    total = AdrManagement::Adr.count
    AdrManagement::Adr.find_each.with_index(1) do |adr, index|
      AdrManagement::RefreshSearchIndex.perform(adr: adr)
      puts "[#{index}/#{total}] ADR #{adr.engagement.code}-#{adr.number} を再索引しました"
    end
    stale = AdrManagement::AdrChunk.stale.count
    puts stale.zero? ? "完了: 全チャンクが最新です" : "完了: #{stale} 件のチャンクが未更新のまま残っています（検索時に再試行されます）"
  end
end
