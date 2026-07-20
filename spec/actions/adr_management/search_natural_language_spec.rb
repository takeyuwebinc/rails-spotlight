# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::SearchNaturalLanguage do
  let(:endpoint) { Sakura::EmbeddingClient::ENDPOINT.to_s }

  def create_indexed_adr(vector, **attributes)
    adr = create(:adr_management_adr, **attributes)
    chunk = adr.chunks.create!(kind: "decision", content: "#{adr.title}\n\n#{adr.decision}", state: "fresh")
    chunk.update!(embedding: vector.pack("f*"))
    adr
  end

  def stub_query_embedding(vector)
    stub_request(:post, endpoint).to_return(
      status: 200,
      headers: { "Content-Type" => "application/json" },
      body: { data: [ { embedding: vector, index: 0 } ] }.to_json
    )
  end

  describe "ranking" do
    it "returns adrs ordered by best chunk similarity with scores" do
      near = create_indexed_adr([ 1.0, 0.0, 0.0 ], title: "近い決定")
      far = create_indexed_adr([ 0.0, 1.0, 0.0 ], title: "遠い決定")
      stub_query_embedding([ 1.0, 0.1, 0.0 ])

      result = described_class.perform(query: "認証まわりで決めたことは？")

      expect(result).to be_success
      expect(result.data.map { |scored| scored.adr }).to eq([ near, far ])
      expect(result.data.first.score).to be > result.data.last.score
    end

    it "limits the number of results" do
      5.times { |i| create_indexed_adr([ 1.0, i * 0.1, 0.0 ]) }
      stub_query_embedding([ 1.0, 0.0, 0.0 ])

      result = described_class.perform(query: "検索", limit: 3)
      expect(result.data.size).to eq(3)
    end
  end

  describe "engagement scope" do
    it "restricts results to the given engagement" do
      target = create_indexed_adr([ 1.0, 0.0, 0.0 ])
      create_indexed_adr([ 1.0, 0.0, 0.0 ])
      stub_query_embedding([ 1.0, 0.0, 0.0 ])

      result = described_class.perform(query: "検索", engagement: target.engagement)

      expect(result.data.map(&:adr)).to eq([ target ])
    end

    it "searches across engagements when no engagement is given" do
      first = create_indexed_adr([ 1.0, 0.0, 0.0 ])
      second = create_indexed_adr([ 0.9, 0.1, 0.0 ])
      stub_query_embedding([ 1.0, 0.0, 0.0 ])

      result = described_class.perform(query: "検索")
      expect(result.data.map(&:adr)).to contain_exactly(first, second)
    end
  end

  describe "stale chunk retry" do
    it "re-embeds stale chunks before searching so they participate in results" do
      adr = create(:adr_management_adr)
      adr.chunks.create!(kind: "decision", content: "本文", state: "stale")

      # 1回目の呼び出し（stale 再試行）と2回目（クエリ埋め込み）の両方に
      # 同一次元のベクトルを返す
      stub_request(:post, endpoint).to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { data: [ { embedding: [ 1.0, 0.0 ], index: 0 } ] }.to_json
      )

      result = described_class.perform(query: "検索")

      expect(adr.chunks.reload.pluck(:state)).to all(eq("fresh"))
      expect(result.data.map(&:adr)).to eq([ adr ])
    end
  end

  describe "failure" do
    it "fails with search_unavailable when the embedding API is down" do
      create_indexed_adr([ 1.0, 0.0, 0.0 ])
      stub_request(:post, endpoint).to_return(status: 500)

      result = described_class.perform(query: "検索")

      expect(result).to be_failure
      expect(result.errors.first.kind).to eq(:search_unavailable)
    end
  end
end
