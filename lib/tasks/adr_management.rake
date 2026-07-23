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

  desc "ゴールデンクエリで自然言語検索の品質（recall@10）を測定する（実 DB・実埋め込み API を使用）"
  task search_eval: :environment do
    entries = YAML.load_file(Rails.root.join("config/adr_search_golden_queries.yml")).fetch("queries")
    result = AdrManagement::EvaluateGoldenQueries.perform(entries: entries)
    abort(result.errors.map { |e| e.respond_to?(:message) ? e.message : e.to_s }.join("\n")) if result.failure?

    data = result.data
    data[:results].each do |query_result|
      puts "Q: #{query_result.query}"
      query_result.hits.each do |hit|
        puts format("  hit  rank %2d  %s (score %.3f)", hit.rank, hit.adr.display_number, hit.score)
      end
      query_result.missed.each do |adr|
        puts "  miss          #{adr.display_number}（上位#{data[:k]}件外）"
      end
    end
    puts data[:recall] ? format("recall@%d: %.3f", data[:k], data[:recall]) : "期待 ADR が定義されていません"
  end

  desc "検索実行数・0件率・取り逃がし報告件数を集計する（SINCE=YYYY-MM-DD、省略時は直近30日）"
  task search_quality_report: :environment do
    since = ENV["SINCE"].present? ? Date.parse(ENV["SINCE"]).beginning_of_day : 30.days.ago
    summary = AdrManagement::SearchLog.summary(since: since)
    miss_reports = AdrManagement::SearchMissReport.where(created_at: since..)

    puts "対象期間: #{since.to_date} 〜 #{Date.current}"
    puts "検索実行数: #{summary[:total]} 件"
    summary[:by_mode].each { |mode, count| puts "  #{mode}: #{count} 件" }
    zero_rate = summary[:total].zero? ? nil : summary[:zero_result_count].fdiv(summary[:total])
    puts "0件検索: #{summary[:zero_result_count]} 件#{zero_rate ? format("（%.1f%%）", zero_rate * 100) : ""}"
    puts "取り逃がし報告: #{miss_reports.count} 件"
    miss_reports.recent_first.each do |report|
      target = report.adr ? report.adr.display_number : "(未到達)"
      puts "  - #{report.created_at.to_date} #{target}: #{report.query}"
    end
  end
end
