# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkHour::Project, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      project = build(:work_hour_project)
      expect(project).to be_valid
    end

    it "is invalid without code" do
      project = build(:work_hour_project, code: nil)
      expect(project).not_to be_valid
      expect(project.errors[:code]).to include("can't be blank")
    end

    it "is invalid without name" do
      project = build(:work_hour_project, name: nil)
      expect(project).not_to be_valid
      expect(project.errors[:name]).to include("can't be blank")
    end

    it "is invalid without color" do
      project = build(:work_hour_project, color: nil)
      expect(project).not_to be_valid
      expect(project.errors[:color]).to include("can't be blank")
    end

    it "is invalid without status" do
      project = build(:work_hour_project, status: nil)
      expect(project).not_to be_valid
      expect(project.errors[:status]).to include("can't be blank")
    end

    it "is invalid with duplicate code" do
      create(:work_hour_project, code: "test-code")
      project = build(:work_hour_project, code: "test-code")
      expect(project).not_to be_valid
      expect(project.errors[:code]).to include("has already been taken")
    end

    it "is invalid with invalid status" do
      project = build(:work_hour_project, status: "invalid")
      expect(project).not_to be_valid
      expect(project.errors[:status]).to include("is not included in the list")
    end
  end

  describe "associations" do
    it "belongs to client optionally" do
      project = build(:work_hour_project, client: nil)
      expect(project).to be_valid
    end

    it "has many monthly_estimates" do
      project = create(:work_hour_project)
      estimate = create(:work_hour_project_monthly_estimate, project: project)
      expect(project.monthly_estimates).to include(estimate)
    end

    it "destroys monthly_estimates when destroyed" do
      project = create(:work_hour_project)
      estimate = create(:work_hour_project_monthly_estimate, project: project)
      expect { project.destroy }.to change(WorkHour::ProjectMonthlyEstimate, :count).by(-1)
    end

    it "has many work_entries" do
      project = create(:work_hour_project)
      entry = create(:work_hour_work_entry, project: project)
      expect(project.work_entries).to include(entry)
    end

    it "restricts destruction when work_entries exist" do
      project = create(:work_hour_project)
      create(:work_hour_work_entry, project: project)
      expect(project.destroy).to be false
      expect(project.errors[:base]).to include("Cannot delete record because dependent work entries exist")
    end
  end

  describe "scopes" do
    describe ".active" do
      let!(:active_project) { create(:work_hour_project, status: "active") }
      let!(:closed_project) { create(:work_hour_project, status: "closed") }

      it "returns only active projects" do
        expect(described_class.active).to contain_exactly(active_project)
      end
    end
  end

  describe "#active?" do
    it "returns true when status is active" do
      project = build(:work_hour_project, status: "active")
      expect(project.active?).to be true
    end

    it "returns false when status is closed" do
      project = build(:work_hour_project, status: "closed")
      expect(project.active?).to be false
    end
  end
end
