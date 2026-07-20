# frozen_string_literal: true

module AdrManagement
  # ADR の検索インデックス（チャンクと埋め込みベクトル）を組み立て直す。
  #
  # タイムアウト付きのベストエフォート同期: チャンク行の再作成は常に行い、
  # 埋め込み API の呼び出しに失敗してもこの操作自体は失敗させない
  # （ADR の登録・更新を索引更新の失敗で巻き込まないため）。
  # 失敗したチャンクは stale のまま残り、次回の検索実行時または
  # 再構築で再試行される。
  class RefreshSearchIndex < ApplicationAction
    # 埋め込み時に文書側へ付与するプレフィックス（モデルの検索精度規約。
    # サーバ側では付与されないため実装側の責務）
    PASSAGE_PREFIX = "passage: "

    def initialize(adr:, embedding_client: Sakura::EmbeddingClient.new)
      @adr = adr
      @embedding_client = embedding_client
    end

    def perform
      chunks = rebuild_chunk_rows
      embed_chunks(chunks)
      success(@adr)
    end

    private

    def rebuild_chunk_rows
      ActiveRecord::Base.transaction do
        @adr.chunks.delete_all
        AdrChunk.build_contents_for(@adr).map do |attributes|
          @adr.chunks.create!(attributes.merge(state: "stale"))
        end
      end
    end

    def embed_chunks(chunks)
      return if chunks.empty?

      vectors = @embedding_client.embed(chunks.map { |chunk| "#{PASSAGE_PREFIX}#{chunk.content}" })
      chunks.each_with_index { |chunk, index| chunk.mark_fresh!(vectors[index]) }
    rescue Sakura::EmbeddingClient::EmbeddingError => e
      Rails.error.report(e, handled: true, context: { adr_id: @adr.id })
    end
  end
end
