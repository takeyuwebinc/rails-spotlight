# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::SearchQualityReportJob do
  it "creates a GitHub issue with the report body" do
    create(:adr_management_search_log, mode: "keyword", result_count: 2)
    client = instance_double(Github::IssueClient)
    allow(Github::IssueClient).to receive(:new).and_return(client)
    expect(client).to receive(:create_issue).with(
      repo: "takeyuwebinc/rails-spotlight",
      title: "ADR検索 品質レポート #{Date.current.strftime("%Y-%m")}",
      body: include("検索実行数: 1 件"),
      labels: [ "search-quality" ]
    ).and_return("https://github.com/takeyuwebinc/rails-spotlight/issues/1")

    described_class.perform_now
  end

  it "fails loudly when issue creation fails, so error monitoring catches it" do
    client = instance_double(Github::IssueClient)
    allow(Github::IssueClient).to receive(:new).and_return(client)
    allow(client).to receive(:create_issue).and_raise(Github::IssueClient::ApiError, "token is not configured")

    expect { described_class.perform_now }.to raise_error(Github::IssueClient::ApiError)
  end
end
