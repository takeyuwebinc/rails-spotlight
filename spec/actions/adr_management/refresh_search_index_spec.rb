# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::RefreshSearchIndex do
  let(:adr) { create(:adr_management_adr) }
  let(:endpoint) { Sakura::EmbeddingClient::ENDPOINT.to_s }

  it "creates fresh chunks with embeddings when the API succeeds" do
    result = described_class.perform(adr: adr)

    expect(result).to be_success
    expect(adr.chunks).to be_present
    expect(adr.chunks.pluck(:state)).to all(eq("fresh"))
    expect(adr.chunks.first.vector).to be_present
  end

  it "sends the passage prefix to the embedding API" do
    described_class.perform(adr: adr)

    expect(WebMock).to have_requested(:post, endpoint).with { |request|
      JSON.parse(request.body)["input"].all? { |text| text.start_with?("passage: ") }
    }
  end

  it "keeps chunks stale and still succeeds when the API fails" do
    stub_request(:post, endpoint).to_return(status: 500)

    result = described_class.perform(adr: adr)

    expect(result).to be_success
    expect(adr.chunks).to be_present
    expect(adr.chunks.pluck(:state)).to all(eq("stale"))
  end

  it "replaces previously indexed chunks" do
    described_class.perform(adr: adr)
    first_ids = adr.chunks.pluck(:id)

    described_class.perform(adr: adr)

    expect(adr.chunks.reload.pluck(:id) & first_ids).to be_empty
  end
end
