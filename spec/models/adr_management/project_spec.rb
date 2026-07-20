# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::Project, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      project = build(:adr_management_project)
      expect(project).to be_valid
    end

    it "is invalid without name" do
      project = build(:adr_management_project, name: nil)
      expect(project).not_to be_valid
      expect(project.errors[:name]).to include("can't be blank")
    end

    it "requires an engagement" do
      project = build(:adr_management_project, engagement: nil)
      expect(project).not_to be_valid
    end

    it "is valid without a period" do
      project = build(:adr_management_project, start_date: nil, end_date: nil)
      expect(project).to be_valid
    end

    it "is invalid when end_date is before start_date" do
      project = build(:adr_management_project, start_date: Date.new(2026, 4, 1), end_date: Date.new(2026, 3, 31))
      expect(project).not_to be_valid
      expect(project.errors[:end_date]).to be_present
    end
  end
end
