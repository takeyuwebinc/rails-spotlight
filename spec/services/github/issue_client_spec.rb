# frozen_string_literal: true

require "rails_helper"

RSpec.describe Github::IssueClient do
  let(:api_url) { "https://api.github.com/repos/owner/repo/issues" }

  it "creates an issue and returns its html_url" do
    stub = stub_request(:post, api_url)
      .with(
        headers: { "Authorization" => "Bearer test-token" },
        body: { title: "t", body: "b", labels: [ "search-quality" ] }.to_json
      )
      .to_return(status: 201, body: { html_url: "https://github.com/owner/repo/issues/1" }.to_json)

    url = described_class.new(token: "test-token").create_issue(
      repo: "owner/repo", title: "t", body: "b", labels: [ "search-quality" ]
    )

    expect(url).to eq("https://github.com/owner/repo/issues/1")
    expect(stub).to have_been_requested
  end

  it "raises ApiError on a non-201 response" do
    stub_request(:post, api_url).to_return(status: 422, body: "Validation Failed")

    expect {
      described_class.new(token: "test-token").create_issue(repo: "owner/repo", title: "t", body: "b")
    }.to raise_error(Github::IssueClient::ApiError, /HTTP 422/)
  end

  it "raises ApiError when the token is not configured" do
    expect {
      described_class.new(token: nil).create_issue(repo: "owner/repo", title: "t", body: "b")
    }.to raise_error(Github::IssueClient::ApiError, /token is not configured/)
  end
end
