# frozen_string_literal: true

module AdrManagement
  # 自然言語の問いで関連 ADR を検索する。検索文を埋め込み、ローカルの
  # 全チャンクとのコサイン類似度を計算し、ADR 単位でチャンクの最良スコアを
  # 関連度として集約する。
  #
  # 実行時に stale（未更新）チャンクの埋め込みを再試行してから検索する。
  # 埋め込み検索は語彙一致に強く言い換えに弱いため、利用側（配布 Skill）には
  # 複数の言い回しでの検索とキーワード・属性検索の併用を求める。
  class SearchNaturalLanguage < ApplicationAction
    QUERY_PREFIX = "query: "

    ScoredAdr = Data.define(:adr, :score)

    def initialize(query:, engagement: nil, limit: 10, embedding_client: Sakura::EmbeddingClient.new)
      @query = query
      @engagement = engagement
      @limit = limit
      @embedding_client = embedding_client
    end

    def perform
      retry_stale_chunks

      query_vector = @embedding_client.embed([ "#{QUERY_PREFIX}#{@query}" ]).first
      scored = best_scores_per_adr(query_vector)
      success(load_scored_adrs(scored))
    rescue Sakura::EmbeddingClient::EmbeddingError => e
      Rails.error.report(e, handled: true)
      failure(OperationError.build(
        kind: :search_unavailable,
        param: "query",
        message: "自然言語検索を実行できません（埋め込み API の呼び出しに失敗しました）",
        next_action: "キーワード・属性検索に切り替えて再実行してください"
      ))
    end

    private

    def retry_stale_chunks
      stale_chunks = scoped_chunks.stale.to_a
      return if stale_chunks.empty?

      vectors = @embedding_client.embed(
        stale_chunks.map { |chunk| "#{RefreshSearchIndex::PASSAGE_PREFIX}#{chunk.content}" }
      )
      stale_chunks.each_with_index { |chunk, index| chunk.mark_fresh!(vectors[index]) }
    rescue Sakura::EmbeddingClient::EmbeddingError => e
      # 再試行の失敗は検索自体を妨げない（fresh なチャンクだけで検索を続行する）
      Rails.error.report(e, handled: true)
    end

    def scoped_chunks
      chunks = AdrChunk.joins(:adr)
      chunks = chunks.where(adr_management_adrs: { engagement_id: @engagement.id }) if @engagement
      chunks
    end

    def best_scores_per_adr(query_vector)
      scores = {}
      scoped_chunks.fresh.find_each do |chunk|
        similarity = chunk.similarity_to(query_vector)
        next if similarity.nil?

        current = scores[chunk.adr_id]
        scores[chunk.adr_id] = similarity if current.nil? || similarity > current
      end
      scores.sort_by { |_, score| -score }.first(@limit)
    end

    def load_scored_adrs(scored)
      adrs = Adr.where(id: scored.map(&:first)).index_by(&:id)
      scored.map { |adr_id, score| ScoredAdr.new(adr: adrs.fetch(adr_id), score: score) }
    end
  end
end
