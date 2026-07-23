# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::EvaluateGoldenQueries do
  # クエリ文字列に応じた固定ベクトルを返す決定的な埋め込みクライアント
  class FakeEmbeddingClient
    def initialize(vectors_by_text)
      @vectors_by_text = vectors_by_text
    end

    def embed(texts)
      texts.map { |text| @vectors_by_text.fetch(text) }
    end
  end

  def index_adr(adr, vector)
    chunk = adr.chunks.create!(kind: "decision", content: adr.decision, state: "fresh")
    chunk.update!(embedding: vector.pack("f*"))
  end

  def entry(query, adr)
    { "query" => query, "expect" => [ { "engagement" => adr.engagement.code, "number" => adr.number } ] }
  end

  it "returns per-query hits with ranks and the overall recall" do
    hit_adr = create(:adr_management_adr, title: "見つかる決定")
    miss_adr = create(:adr_management_adr, title: "見つからない決定")
    noise = create(:adr_management_adr, title: "ノイズの決定")
    index_adr(hit_adr, [ 1.0, 0.0 ])
    index_adr(noise, [ 0.9, 0.1 ])
    # miss_adr は索引に載せず、期待していても上位に出ない状況を作る

    client = FakeEmbeddingClient.new(
      "query: ヒットするクエリ" => [ 1.0, 0.0 ],
      "query: ミスするクエリ" => [ 0.0, 1.0 ]
    )
    result = described_class.perform(
      entries: [ entry("ヒットするクエリ", hit_adr), entry("ミスするクエリ", miss_adr) ],
      embedding_client: client
    )

    expect(result).to be_success
    hit_result, miss_result = result.data[:results]
    expect(hit_result.hits.size).to eq(1)
    expect(hit_result.hits.first.rank).to eq(1)
    expect(hit_result.hits.first.adr).to eq(hit_adr)
    expect(miss_result.hits).to be_empty
    expect(miss_result.missed).to eq([ miss_adr ])
    expect(result.data[:recall]).to eq(0.5)
  end

  it "fails when an expected ADR does not exist" do
    result = described_class.perform(
      entries: [ { "query" => "q", "expect" => [ { "engagement" => "nope", "number" => 1 } ] } ],
      embedding_client: FakeEmbeddingClient.new({})
    )

    expect(result).to be_failure
    expect(result.errors.first.kind).to eq(:invalid_input)
    expect(result.errors.first.message).to include("nope-1")
  end

  it "propagates a search failure when the embedding API is unavailable" do
    adr = create(:adr_management_adr)
    failing_client = Class.new do
      def embed(_texts)
        raise Sakura::EmbeddingClient::EmbeddingError, "down"
      end
    end.new

    result = described_class.perform(
      entries: [ { "query" => "q", "expect" => [ { "engagement" => adr.engagement.code, "number" => adr.number } ] } ],
      embedding_client: failing_client
    )

    expect(result).to be_failure
    expect(result.errors.first.kind).to eq(:search_unavailable)
  end
end
