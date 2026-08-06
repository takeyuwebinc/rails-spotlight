# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::SearchQualityReportJob do
  let(:client) { instance_double(Github::IssueClient) }

  before do
    allow(Github::IssueClient).to receive(:new).and_return(client)
    allow(client).to receive(:create_issue).and_return("https://github.com/x/y/issues/1")
  end

  def index_adr(adr, vector)
    chunk = adr.chunks.create!(kind: "decision", content: adr.decision, state: "fresh")
    chunk.update!(embedding: vector.pack("f*"))
  end

  def stub_query_embedding(vector)
    stub_request(:post, Sakura::EmbeddingClient::ENDPOINT.to_s).to_return(
      status: 200,
      headers: { "Content-Type" => "application/json" },
      body: { data: [ { embedding: vector, index: 0 } ] }.to_json
    )
  end

  it "evaluates, persists the evaluation, auto-records the check and creates the issue" do
    adr = create(:adr_management_adr, title: "見つかる決定")
    index_adr(adr, [ 1.0, 0.0 ])
    create(:adr_management_golden_query, adr: adr, query: "ヒットするクエリ")
    stub_query_embedding([ 1.0, 0.0 ])

    target_engagement = create(:adr_management_engagement, code: "spotlight-rails")
    target = create(:adr_management_adr, engagement: target_engagement, number: 38,
      reevaluation_conditions: "数値条件")

    expect(client).to receive(:create_issue).with(
      repo: "takeyuwebinc/rails-spotlight",
      title: "ADR検索品質レポート #{Date.current.strftime("%Y-%m")}",
      body: include("recall@10: 1.000").and(include("自動点検（SPOTLIGHT-RAILS-38）: no_trigger")),
      labels: [ "search-quality" ]
    )

    expect { described_class.perform_now }
      .to change(AdrManagement::SearchEvaluation, :count).by(1)
      .and change(target.reevaluation_checks, :count).by(1)

    evaluation = AdrManagement::SearchEvaluation.last
    expect(evaluation.recall).to eq(1.0)
    expect(evaluation.origin).to eq("system:search-quality-report")
    check = target.reevaluation_checks.last
    expect(check.result).to eq("no_trigger")
    expect(check.origin).to eq("system:search-quality-report")
  end

  it "still creates the issue when the evaluation fails, reporting the degradation" do
    create(:adr_management_golden_query)
    stub_request(:post, Sakura::EmbeddingClient::ENDPOINT.to_s).to_return(status: 500)

    expect(client).to receive(:create_issue).with(
      hash_including(body: include("ゴールデンクエリ評価: 未実行"))
    )

    expect { described_class.perform_now }.not_to change(AdrManagement::SearchEvaluation, :count)
  end

  it "skips the auto check when the target ADR does not exist" do
    expect { described_class.perform_now }.not_to change(AdrManagement::ReevaluationCheck, :count)
  end

  it "fails loudly when issue creation fails, so error monitoring catches it" do
    allow(client).to receive(:create_issue).and_raise(Github::IssueClient::ApiError, "token is not configured")

    expect { described_class.perform_now }.to raise_error(Github::IssueClient::ApiError)
  end
end
