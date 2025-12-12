# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkHour::ProjectMonthlyEstimate, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      estimate = build(:work_hour_project_monthly_estimate)
      expect(estimate).to be_valid
    end

    it "is invalid without year_month" do
      estimate = build(:work_hour_project_monthly_estimate, year_month: nil)
      expect(estimate).not_to be_valid
      expect(estimate.errors[:year_month]).to include("can't be blank")
    end

    it "is invalid without estimated_hours" do
      estimate = build(:work_hour_project_monthly_estimate, estimated_hours: nil)
      expect(estimate).not_to be_valid
      expect(estimate.errors[:estimated_hours]).to include("can't be blank")
    end

    it "is invalid with negative estimated_hours" do
      estimate = build(:work_hour_project_monthly_estimate, estimated_hours: -1)
      expect(estimate).not_to be_valid
      expect(estimate.errors[:estimated_hours]).to include("must be greater than or equal to 0")
    end

    it "validates uniqueness of year_month scoped to project" do
      existing = create(:work_hour_project_monthly_estimate)
      duplicate = build(:work_hour_project_monthly_estimate,
                        project: existing.project,
                        year_month: existing.year_month)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:year_month]).to include("has already been taken")
    end
  end

  describe "associations" do
    it "belongs to project" do
      estimate = create(:work_hour_project_monthly_estimate)
      expect(estimate.project).to be_a(WorkHour::Project)
    end
  end

  describe ".for_month" do
    let(:project) { create(:work_hour_project) }
    let!(:estimate_jan) { create(:work_hour_project_monthly_estimate, project: project, year_month: Date.new(2025, 1, 1)) }
    let!(:estimate_feb) { create(:work_hour_project_monthly_estimate, project: project, year_month: Date.new(2025, 2, 1)) }

    it "returns estimates for the specified month" do
      expect(described_class.for_month(Date.new(2025, 1, 1))).to contain_exactly(estimate_jan)
    end
  end

  describe ".total_hours_for_month" do
    let(:project1) { create(:work_hour_project) }
    let(:project2) { create(:work_hour_project) }

    before do
      create(:work_hour_project_monthly_estimate, project: project1, year_month: Date.new(2025, 1, 1), estimated_hours: 80)
      create(:work_hour_project_monthly_estimate, project: project2, year_month: Date.new(2025, 1, 1), estimated_hours: 60)
      create(:work_hour_project_monthly_estimate, project: project1, year_month: Date.new(2025, 2, 1), estimated_hours: 40)
    end

    it "returns total estimated hours for the specified month" do
      expect(described_class.total_hours_for_month(Date.new(2025, 1, 1))).to eq(140)
    end

    it "returns 0 for month with no estimates" do
      expect(described_class.total_hours_for_month(Date.new(2025, 3, 1))).to eq(0)
    end
  end
end
