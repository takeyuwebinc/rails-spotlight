# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::AdrChunk, type: :model do
  describe ".build_contents_for" do
    it "builds one chunk per present section with the title prefixed" do
      adr = build(:adr_management_adr,
        title: "認証方式の選定",
        context: "コンテキスト本文",
        decision: "決定本文",
        consequences: "結果本文",
        alternatives: nil,
        reevaluation_conditions: nil)

      contents = described_class.build_contents_for(adr)

      expect(contents.map { |c| c[:kind] }).to contain_exactly("context", "decision", "consequences")
      expect(contents).to all(satisfy { |c| c[:content].start_with?("認証方式の選定\n\n") })
    end

    it "splits sections exceeding the max chunk size" do
      adr = build(:adr_management_adr, decision: "あ" * (described_class::MAX_CONTENT_CHARS * 2 + 10))

      kinds = described_class.build_contents_for(adr).map { |c| c[:kind] }
      expect(kinds).to include("decision:1", "decision:2", "decision:3")
    end
  end

  describe "#vector round trip" do
    it "restores the stored float array" do
      chunk = described_class.new
      chunk.vector = [ 0.5, -1.25, 3.0 ]
      expect(chunk.vector.map { |v| v.round(4) }).to eq([ 0.5, -1.25, 3.0 ])
    end
  end

  describe "#similarity_to" do
    it "computes cosine similarity" do
      chunk = described_class.new
      chunk.vector = [ 1.0, 0.0 ]
      expect(chunk.similarity_to([ 1.0, 0.0 ])).to be_within(0.0001).of(1.0)
      expect(chunk.similarity_to([ 0.0, 1.0 ])).to be_within(0.0001).of(0.0)
    end

    it "returns nil when dimensions do not match" do
      chunk = described_class.new
      chunk.vector = [ 1.0, 0.0 ]
      expect(chunk.similarity_to([ 1.0, 0.0, 0.0 ])).to be_nil
    end

    it "returns nil when no embedding is stored" do
      expect(described_class.new.similarity_to([ 1.0 ])).to be_nil
    end
  end
end
