# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::Engagement, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      engagement = build(:adr_management_engagement)
      expect(engagement).to be_valid
    end

    it "is invalid without code" do
      engagement = build(:adr_management_engagement, code: nil)
      expect(engagement).not_to be_valid
      expect(engagement.errors[:code]).to include("can't be blank")
    end

    it "is invalid without name" do
      engagement = build(:adr_management_engagement, name: nil)
      expect(engagement).not_to be_valid
      expect(engagement.errors[:name]).to include("can't be blank")
    end

    it "is invalid with duplicate code" do
      create(:adr_management_engagement, code: "fabble")
      engagement = build(:adr_management_engagement, code: "fabble")
      expect(engagement).not_to be_valid
      expect(engagement.errors[:code]).to include("has already been taken")
    end

    it "requires a client" do
      engagement = build(:adr_management_engagement, client: nil)
      expect(engagement).not_to be_valid
    end
  end

  describe "max_issued_number" do
    it "defaults to 0" do
      engagement = create(:adr_management_engagement)
      expect(engagement.max_issued_number).to eq(0)
    end
  end

  describe "projects" do
    it "cannot be destroyed when projects exist" do
      engagement = create(:adr_management_engagement)
      create(:adr_management_project, engagement: engagement)
      expect(engagement.destroy).to be_falsey
      expect(engagement.errors[:base]).to be_present
    end
  end
end
