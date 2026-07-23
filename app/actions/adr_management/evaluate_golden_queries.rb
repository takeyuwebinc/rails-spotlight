# frozen_string_literal: true

module AdrManagement
  # ゴールデンクエリ（自然言語クエリと期待 ADR の組）で検索品質を測定する。
  # 各クエリで自然言語検索を実行し、期待 ADR の順位（上位 K 件内なら hit）と
  # 全体の recall@K を返す。検索実装の変更（チャンク戦略・モデル・方式）の
  # 前後で実行し、劣化を検知する回帰テストとして使う。
  class EvaluateGoldenQueries < ApplicationAction
    K = 10

    QueryResult = Data.define(:query, :hits, :missed)
    Hit = Data.define(:adr, :rank, :score)

    # entries: [ { "query" => String, "expect" => [ { "engagement" => code, "number" => Integer } ] } ]
    def initialize(entries:, embedding_client: Sakura::EmbeddingClient.new)
      @entries = entries
      @embedding_client = embedding_client
    end

    def perform
      expected_sets = resolve_expected_sets
      return failure(expected_sets) if expected_sets.is_a?(OperationError)

      results = []
      @entries.each_with_index do |entry, index|
        result = evaluate(entry.fetch("query"), expected_sets.fetch(index))
        return result if result.is_a?(ActionResult)

        results << result
      end

      expected_total = results.sum { |r| r.hits.size + r.missed.size }
      hit_total = results.sum { |r| r.hits.size }
      success({
        results: results,
        recall: expected_total.zero? ? nil : hit_total.fdiv(expected_total),
        k: K
      })
    end

    private

    # 期待 ADR の解決失敗は評価続行せずエラーにする。存在しない ADR を
    # 黙って除外すると、ADR の削除・番号誤記で recall が実態より高く出る
    def resolve_expected_sets
      @entries.map do |entry|
        entry.fetch("expect").map do |ref|
          engagement = Engagement.where("LOWER(code) = ?", ref.fetch("engagement").downcase).first
          adr = engagement&.adrs&.find_by(number: ref.fetch("number"))
          unless adr
            return OperationError.build(
              kind: :invalid_input,
              param: "expect",
              message: "ゴールデンクエリの期待 ADR が存在しません: #{ref["engagement"]}-#{ref["number"]}",
              next_action: "ゴールデンクエリ定義から削除するか、正しい案件 code・番号に修正してください"
            )
          end
          adr
        end
      end
    end

    def evaluate(query, expected_adrs)
      result = SearchNaturalLanguage.perform(
        query: query, limit: K, embedding_client: @embedding_client
      )
      return result if result.failure?

      ranked = result.data
      hits = []
      missed = []
      expected_adrs.each do |adr|
        rank = ranked.index { |entry| entry.adr.id == adr.id }
        if rank
          hits << Hit.new(adr: adr, rank: rank + 1, score: ranked[rank].score)
        else
          missed << adr
        end
      end
      QueryResult.new(query: query, hits: hits, missed: missed)
    end
  end
end
