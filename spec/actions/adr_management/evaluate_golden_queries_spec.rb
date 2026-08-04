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

  it "evaluates golden queries from the database and returns hits, recall and details" do
    hit_adr = create(:adr_management_adr, title: "見つかる決定")
    miss_adr = create(:adr_management_adr, title: "見つからない決定")
    noise = create(:adr_management_adr, title: "ノイズの決定")
    index_adr(hit_adr, [ 1.0, 0.0 ])
    index_adr(noise, [ 0.9, 0.1 ])
    # miss_adr は索引に載せず、期待していても上位に出ない状況を作る
    create(:adr_management_golden_query, adr: hit_adr, query: "ヒットするクエリ")
    create(:adr_management_golden_query, adr: miss_adr, query: "ミスするクエリ")

    client = FakeEmbeddingClient.new(
      "query: ヒットするクエリ" => [ 1.0, 0.0 ],
      "query: ミスするクエリ" => [ 0.0, 1.0 ]
    )
    result = described_class.perform(embedding_client: client)

    expect(result).to be_success
    hit_result, miss_result = result.data[:results]
    expect(hit_result.hits.first.rank).to eq(1)
    expect(hit_result.hits.first.adr).to eq(hit_adr)
    expect(miss_result.hits).to be_empty
    expect(miss_result.missed).to eq([ miss_adr ])
    expect(result.data[:recall]).to eq(0.5)
    expect(result.data[:details]).to contain_exactly(
      { query: "ヒットするクエリ", hits: [ { adr_id: hit_adr.id, rank: 1, score: 1.0 } ], missed: [] },
      { query: "ミスするクエリ", hits: [], missed: [ miss_adr.id ] }
    )
  end

  it "evaluates expectations sharing the same query with a single search" do
    first = create(:adr_management_adr, title: "決定A")
    second = create(:adr_management_adr, title: "決定B")
    index_adr(first, [ 1.0, 0.0 ])
    index_adr(second, [ 0.9, 0.1 ])
    create(:adr_management_golden_query, adr: first, query: "同じクエリ")
    create(:adr_management_golden_query, adr: second, query: "同じクエリ")

    client = FakeEmbeddingClient.new("query: 同じクエリ" => [ 1.0, 0.0 ])
    result = described_class.perform(embedding_client: client)

    expect(result.data[:results].size).to eq(1)
    expect(result.data[:recall]).to eq(1.0)
  end

  it "returns a nil recall when no golden queries are registered" do
    result = described_class.perform(embedding_client: FakeEmbeddingClient.new({}))

    expect(result).to be_success
    expect(result.data[:recall]).to be_nil
    expect(result.data[:results]).to be_empty
  end

  it "propagates a search failure when the embedding API is unavailable" do
    create(:adr_management_golden_query)
    failing_client = Class.new do
      def embed(_texts)
        raise Sakura::EmbeddingClient::EmbeddingError, "down"
      end
    end.new

    result = described_class.perform(embedding_client: failing_client)

    expect(result).to be_failure
    expect(result.errors.first.kind).to eq(:search_unavailable)
  end
end
