# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sakura::EmbeddingClient do
  let(:client) { described_class.new }
  let(:endpoint) { described_class::ENDPOINT.to_s }

  it "posts texts and returns vectors in order" do
    stub_request(:post, endpoint)
      .with(body: hash_including("model" => "multilingual-e5-large", "input" => [ "passage: A", "passage: B" ]))
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { data: [ { embedding: [ 0.1, 0.2 ], index: 0 }, { embedding: [ 0.3, 0.4 ], index: 1 } ] }.to_json
      )

    vectors = client.embed([ "passage: A", "passage: B" ])
    expect(vectors).to eq([ [ 0.1, 0.2 ], [ 0.3, 0.4 ] ])
  end

  it "returns a nested vector array for a single-element input" do
    stub_request(:post, endpoint)
      .with(body: hash_including("input" => [ "query: Q" ]))
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { data: [ { embedding: [ 0.5, 0.6 ], index: 0 } ] }.to_json
      )

    expect(client.embed([ "query: Q" ])).to eq([ [ 0.5, 0.6 ] ])
  end

  it "raises EmbeddingError on a non-success response" do
    stub_request(:post, endpoint).to_return(status: 400, body: "input too long")
    expect { client.embed([ "text" ]) }.to raise_error(described_class::EmbeddingError, /input too long/)
  end

  it "raises EmbeddingError on timeout" do
    stub_request(:post, endpoint).to_timeout
    expect { client.embed([ "text" ]) }.to raise_error(described_class::EmbeddingError)
  end

  it "does not mutate the global RubyLLM configuration" do
    stub_request(:post, endpoint).to_return(
      status: 200,
      headers: { "Content-Type" => "application/json" },
      body: { data: [ { embedding: [ 0.1 ], index: 0 } ] }.to_json
    )

    expect { client.embed([ "text" ]) }.not_to change { RubyLLM.config.request_timeout }
  end
end
