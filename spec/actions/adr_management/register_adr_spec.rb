# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::RegisterAdr do
  let(:engagement) { create(:adr_management_engagement) }
  let(:origin) { "test-agent" }
  let(:attributes) do
    {
      title: "認証方式の選定",
      status: "accepted",
      confidence: "high",
      decided_on: Date.new(2026, 7, 1),
      context: "現状の問題点",
      decision: "実装方針",
      consequences: "影響"
    }
  end

  def register(**overrides)
    described_class.perform(
      engagement: engagement, attributes: attributes, origin: origin, **overrides
    )
  end

  describe "numbering" do
    it "issues sequential numbers per engagement" do
      first = register.data
      second = register.data
      expect([ first.number, second.number ]).to eq([ 1, 2 ])
    end

    it "numbers engagements independently" do
      register
      other = create(:adr_management_engagement)
      result = described_class.perform(
        engagement: other, attributes: attributes, origin: origin
      )
      expect(result.data.number).to eq(1)
    end

    it "does not reuse numbers of deleted adrs" do
      register
      register.data.destroy!
      expect(register.data.number).to eq(3)
    end
  end

  describe "revision recording" do
    it "records a created revision with the origin" do
      adr = register.data
      revision = adr.revisions.sole
      expect(revision.change_type).to eq("created")
      expect(revision.origin).to eq("test-agent")
      expect(revision.snapshot).to be_nil
    end
  end

  describe "atomic supersession" do
    let!(:old_adr) do
      create(:adr_management_adr, engagement: engagement, status: "accepted", title: "旧決定")
    end

    it "registers the new adr, supersedes the old one, and records the relation atomically" do
      result = register(superseded_numbers: [ old_adr.number ])

      expect(result).to be_success
      new_adr = result.data
      expect(new_adr.status).to eq("accepted")
      expect(old_adr.reload.status).to eq("superseded")
      expect(new_adr.superseded_adrs).to contain_exactly(old_adr)
      expect(old_adr.superseding_adr).to eq(new_adr)
    end

    it "records a status_changed revision for the old adr with its previous state" do
      register(superseded_numbers: [ old_adr.number ])

      revision = old_adr.revisions.where(change_type: "status_changed").sole
      expect(revision.snapshot["status"]).to eq("accepted")
      expect(revision.changed_fields).to eq([ "status" ])
    end

    it "can supersede multiple adrs at once" do
      another = create(:adr_management_adr, engagement: engagement, status: "accepted")
      result = register(superseded_numbers: [ old_adr.number, another.number ])
      expect(result.data.superseded_adrs).to contain_exactly(old_adr, another)
    end

    it "fails when a superseded number does not exist in the engagement" do
      result = register(superseded_numbers: [ 999 ])

      expect(result).to be_failure
      expect(result.errors.first.kind).to eq(:invalid_supersession)
      expect(AdrManagement::Adr.where(engagement: engagement).count).to eq(1)
    end

    it "fails when the superseded adr is not accepted" do
      proposed = create(:adr_management_adr, engagement: engagement, status: "proposed")
      result = register(superseded_numbers: [ proposed.number ])

      expect(result).to be_failure
      expect(result.errors.first.kind).to eq(:invalid_supersession)
      expect(proposed.reload.status).to eq("proposed")
    end

    it "fails when the superseded adr belongs to another engagement" do
      # 置換対象は案件内の番号で指定するため、別案件の ADR は
      # 「対象案件に存在しない番号」として拒否される
      other_adr = create(:adr_management_adr, status: "accepted", number: 50)
      result = register(superseded_numbers: [ other_adr.number ])

      expect(result).to be_failure
      expect(result.errors.first.kind).to eq(:invalid_supersession)
      expect(other_adr.reload.status).to eq("accepted")
    end

    it "fails when the initial status is not accepted" do
      result = register(
        superseded_numbers: [ old_adr.number ],
        attributes: attributes.merge(status: "proposed")
      )

      expect(result).to be_failure
      expect(result.errors.first.kind).to eq(:invalid_supersession)
      expect(old_adr.reload.status).to eq("accepted")
    end
  end

  describe "input validation" do
    it "fails with structured errors when required attributes are missing" do
      result = register(attributes: attributes.merge(title: ""))

      expect(result).to be_failure
      error = result.errors.first
      expect(error.kind).to eq(:invalid_input)
      expect(error.param).to eq("title")
    end

    it "allows proposed as the initial status" do
      result = register(attributes: attributes.merge(status: "proposed"))
      expect(result).to be_success
    end

    %w[rejected deprecated superseded].each do |status|
      it "rejects #{status} as the initial status" do
        result = register(attributes: attributes.merge(status: status))

        expect(result).to be_failure
        expect(result.errors.first.kind).to eq(:invalid_input)
        expect(result.errors.first.param).to eq("status")
      end
    end
  end
end
