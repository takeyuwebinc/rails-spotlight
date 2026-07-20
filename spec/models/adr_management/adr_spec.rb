# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::Adr, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      adr = build(:adr_management_adr)
      expect(adr).to be_valid
    end

    %i[title context decision consequences decided_on].each do |attribute|
      it "is invalid without #{attribute}" do
        adr = build(:adr_management_adr, attribute => nil)
        expect(adr).not_to be_valid
      end
    end

    it "is invalid with an unknown status" do
      adr = build(:adr_management_adr, status: "unknown")
      expect(adr).not_to be_valid
    end

    it "is invalid with an unknown confidence" do
      adr = build(:adr_management_adr, confidence: "unknown")
      expect(adr).not_to be_valid
    end

    it "is invalid with a duplicate number within the same engagement" do
      engagement = create(:adr_management_engagement)
      create(:adr_management_adr, engagement: engagement, number: 1)
      adr = build(:adr_management_adr, engagement: engagement, number: 1)
      expect(adr).not_to be_valid
      expect(adr.errors[:number]).to include("has already been taken")
    end

    it "allows the same number across engagements" do
      create(:adr_management_adr, number: 1)
      adr = build(:adr_management_adr, number: 1)
      expect(adr).to be_valid
    end

    it "is invalid when project belongs to another engagement" do
      other_project = create(:adr_management_project)
      adr = build(:adr_management_adr, project: other_project)
      expect(adr).not_to be_valid
      expect(adr.errors[:project]).to be_present
    end

    it "is valid when project belongs to the same engagement" do
      engagement = create(:adr_management_engagement)
      project = create(:adr_management_project, engagement: engagement)
      adr = build(:adr_management_adr, engagement: engagement, project: project)
      expect(adr).to be_valid
    end
  end

  describe "deletion constraints" do
    it "cannot be destroyed when it supersedes another adr" do
      old_adr = create(:adr_management_adr)
      new_adr = create(:adr_management_adr, engagement: old_adr.engagement)
      AdrManagement::Supersession.create!(superseding_adr: new_adr, superseded_adr: old_adr)

      expect(new_adr.destroy).to be_falsey
      expect(old_adr.reload.destroy).to be_falsey
    end

    it "destroys its revisions together" do
      adr = create(:adr_management_adr)
      adr.record_revision!(change_type: "created", origin: "test")

      expect { adr.destroy }.to change(AdrManagement::AdrRevision, :count).by(-1)
    end
  end

  describe "#supersession_involved?" do
    it "is false for an adr without supersessions" do
      expect(create(:adr_management_adr).supersession_involved?).to be(false)
    end
  end
end
