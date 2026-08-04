# frozen_string_literal: true

module AdrManagement
  # ゴールデンクエリ（自然言語クエリと期待 ADR の組）で検索品質を測定する。
  # クエリごとに自然言語検索を実行し、期待 ADR の順位（上位 K 件内なら hit）と
  # 全体の recall@K を返す。検索実装の変更・コーパスの変化による劣化を
  # 検知する回帰テストとして使う。
  class EvaluateGoldenQueries < ApplicationAction
    K = 10

    QueryResult = Data.define(:query, :hits, :missed)
    Hit = Data.define(:adr, :rank, :score)

    def initialize(embedding_client: Sakura::EmbeddingClient.new)
      @embedding_client = embedding_client
    end

    def perform
      results = []
      grouped_expectations.each do |query, expected_adrs|
        result = evaluate(query, expected_adrs)
        return result if result.is_a?(ActionResult)

        results << result
      end

      expected_total = results.sum { |r| r.hits.size + r.missed.size }
      hit_total = results.sum { |r| r.hits.size }
      success({
        results: results,
        recall: expected_total.zero? ? nil : hit_total.fdiv(expected_total),
        k: K,
        details: build_details(results)
      })
    end

    private

    # 同じクエリ文の期待 ADR は1回の検索でまとめて判定する
    def grouped_expectations
      GoldenQuery.includes(:adr).order(:id)
        .group_by(&:query)
        .transform_values { |entries| entries.map(&:adr) }
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

    # 評価履歴（SearchEvaluation.details）に保存できる形の内訳
    def build_details(results)
      results.map do |result|
        {
          query: result.query,
          hits: result.hits.map { |h| { adr_id: h.adr.id, rank: h.rank, score: h.score.round(4) } },
          missed: result.missed.map(&:id)
        }
      end
    end
  end
end
