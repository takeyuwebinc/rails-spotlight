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

  desc "ゴールデンクエリで自然言語検索の品質（recall@10）を測定し履歴に記録する（実 DB・実埋め込み API を使用）"
  task search_eval: :environment do
    result = AdrManagement::EvaluateGoldenQueries.perform
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
    if data[:recall]
      AdrManagement::SearchEvaluation.create!(
        k: data[:k], recall: data[:recall], details: data[:details], origin: "manual"
      )
      puts format("recall@%d: %.3f（評価履歴に記録しました）", data[:k], data[:recall])
    else
      puts "ゴールデンクエリが登録されていません"
    end
  end

  desc "ゴールデンクエリを YAML（config/adr_search_golden_queries.yml）から DB へ移行する（一回限り・再実行しても重複しない）"
  task import_golden_queries: :environment do
    path = Rails.root.join("config/adr_search_golden_queries.yml")
    abort("#{path} がありません") unless File.exist?(path)

    imported = 0
    skipped = []
    YAML.load_file(path).fetch("queries").each do |entry|
      query = entry.fetch("query")
      entry.fetch("expect").each do |ref|
        engagement = AdrManagement::Engagement.where("LOWER(code) = ?", ref.fetch("engagement").downcase).first
        adr = engagement&.adrs&.find_by(number: ref.fetch("number"))
        unless adr
          skipped << "#{ref["engagement"]}-#{ref["number"]}（#{query}）"
          next
        end
        next if AdrManagement::GoldenQuery.exists?(query: query, adr: adr)

        AdrManagement::GoldenQuery.create!(query: query, adr: adr, origin: "seed:yaml")
        imported += 1
      end
    end
    puts "取り込み: #{imported} 件（登録済み合計 #{AdrManagement::GoldenQuery.count} 件）"
    skipped.each { |entry| puts "スキップ（ADR が存在しません）: #{entry}" }
  end

  desc "検索実行数・0件率・取り逃がし報告件数を集計する（SINCE=YYYY-MM-DD、省略時は直近30日）"
  task search_quality_report: :environment do
    since = ENV["SINCE"].present? ? Date.parse(ENV["SINCE"]).beginning_of_day : 30.days.ago
    puts AdrManagement::BuildSearchQualityReport.perform(since: since).data[:text]
  end
end
