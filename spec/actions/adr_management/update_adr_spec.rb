# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::UpdateAdr do
  let(:adr) { create(:adr_management_adr, status: "proposed", title: "旧タイトル") }
  let(:origin) { "test-agent" }

  def update(attributes)
    described_class.perform(adr: adr, attributes: attributes, origin: origin)
  end

  describe "content update" do
    it "updates attributes and records a revision with the previous state" do
      result = update(title: "新タイトル", decision: "新方針")

      expect(result).to be_success
      expect(adr.reload.title).to eq("新タイトル")

      revision = adr.revisions.where(change_type: "updated").sole
      expect(revision.snapshot["title"]).to eq("旧タイトル")
      expect(revision.changed_fields).to contain_exactly("title", "decision")
      expect(revision.origin).to eq("test-agent")
    end
  end

  describe "status transitions" do
    it "allows proposed to accepted" do
      expect(update(status: "accepted")).to be_success
      expect(adr.reload.status).to eq("accepted")
    end

    it "allows proposed to rejected" do
      expect(update(status: "rejected")).to be_success
    end

    it "allows accepted to deprecated" do
      adr.update!(status: "accepted")
      expect(update(status: "deprecated")).to be_success
    end

    it "rejects accepted to proposed" do
      adr.update!(status: "accepted")
      result = update(status: "proposed")
      expect(result).to be_failure
      expect(result.errors.first.kind).to eq(:invalid_status_transition)
      expect(adr.reload.status).to eq("accepted")
    end

    it "rejects direct transition to superseded" do
      adr.update!(status: "accepted")
      result = update(status: "superseded")
      expect(result).to be_failure
      expect(result.errors.first.kind).to eq(:invalid_status_transition)
    end

    it "rejects transitions from terminal statuses" do
      adr.update!(status: "rejected")
      result = update(status: "accepted")
      expect(result).to be_failure
    end

    it "allows updating content while keeping the same status" do
      result = update(status: "proposed", title: "同じステータスで更新")
      expect(result).to be_success
    end
  end

  describe "input validation" do
    it "fails with structured errors and does not record a revision" do
      result = update(title: "")

      expect(result).to be_failure
      expect(result.errors.first.kind).to eq(:invalid_input)
      expect(adr.revisions.where(change_type: "updated")).to be_empty
    end
  end
end
