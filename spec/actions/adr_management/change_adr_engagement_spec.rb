# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::ChangeAdrEngagement do
  let(:source_engagement) { create(:adr_management_engagement) }
  let(:target_engagement) { create(:adr_management_engagement) }
  let(:origin) { "admin:tester" }

  it "moves the adr and renumbers it in the target engagement" do
    create(:adr_management_adr, engagement: target_engagement)
    adr = create(:adr_management_adr, engagement: source_engagement)

    result = described_class.perform(adr: adr, engagement: target_engagement, origin: origin)

    expect(result).to be_success
    adr.reload
    expect(adr.engagement).to eq(target_engagement)
    expect(adr.number).to eq(2)
  end

  it "clears the project reference (projects belong to the source engagement)" do
    project = create(:adr_management_project, engagement: source_engagement)
    adr = create(:adr_management_adr, engagement: source_engagement, project: project)

    described_class.perform(adr: adr, engagement: target_engagement, origin: origin)

    expect(adr.reload.project).to be_nil
  end

  it "records an engagement_changed revision with the previous state" do
    adr = create(:adr_management_adr, engagement: source_engagement)
    original_number = adr.number

    described_class.perform(adr: adr, engagement: target_engagement, origin: origin)

    revision = adr.revisions.where(change_type: "engagement_changed").sole
    expect(revision.snapshot["engagement_id"]).to eq(source_engagement.id)
    expect(revision.snapshot["number"]).to eq(original_number)
  end

  it "refuses when the adr has supersession relations" do
    old_adr = create(:adr_management_adr, engagement: source_engagement, status: "accepted")
    new_adr = create(:adr_management_adr, engagement: source_engagement)
    AdrManagement::Supersession.create!(superseding_adr: new_adr, superseded_adr: old_adr)

    result = described_class.perform(adr: new_adr, engagement: target_engagement, origin: origin)

    expect(result).to be_failure
    expect(new_adr.reload.engagement).to eq(source_engagement)
  end

  it "does nothing when the target equals the current engagement" do
    adr = create(:adr_management_adr, engagement: source_engagement)
    original_number = adr.number

    result = described_class.perform(adr: adr, engagement: source_engagement, origin: origin)

    expect(result).to be_success
    expect(adr.reload.number).to eq(original_number)
    expect(adr.revisions.where(change_type: "engagement_changed")).to be_empty
  end
end
