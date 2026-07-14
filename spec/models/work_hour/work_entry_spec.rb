# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkHour::WorkEntry, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      entry = build(:work_hour_work_entry)
      expect(entry).to be_valid
    end

    it "is invalid without worked_on" do
      entry = build(:work_hour_work_entry, worked_on: nil)
      expect(entry).not_to be_valid
      expect(entry.errors[:worked_on]).to include("can't be blank")
    end

    it "is invalid without target_month" do
      entry = build(:work_hour_work_entry, target_month: nil)
      expect(entry).not_to be_valid
      expect(entry.errors[:target_month]).to include("can't be blank")
    end

    it "is invalid without minutes" do
      entry = build(:work_hour_work_entry, minutes: nil)
      expect(entry).not_to be_valid
      expect(entry.errors[:minutes]).to include("can't be blank")
    end

    it "is invalid with non-integer minutes" do
      entry = build(:work_hour_work_entry, minutes: 30.5)
      expect(entry).not_to be_valid
      expect(entry.errors[:minutes]).to include("must be an integer")
    end

    it "is invalid with zero minutes" do
      entry = build(:work_hour_work_entry, minutes: 0)
      expect(entry).not_to be_valid
      expect(entry.errors[:minutes]).to include("must be greater than 0")
    end

    it "is invalid with negative minutes" do
      entry = build(:work_hour_work_entry, minutes: -1)
      expect(entry).not_to be_valid
      expect(entry.errors[:minutes]).to include("must be greater than 0")
    end
  end

  describe "associations" do
    it "belongs to project optionally" do
      entry = build(:work_hour_work_entry, project: nil)
      expect(entry).to be_valid
    end
  end

  describe "scopes" do
    describe ".for_month" do
      let!(:entry_jan) { create(:work_hour_work_entry, target_month: Date.new(2025, 1, 1)) }
      let!(:entry_feb) { create(:work_hour_work_entry, target_month: Date.new(2025, 2, 1)) }

      it "returns entries for the specified month" do
        expect(described_class.for_month(Date.new(2025, 1, 1))).to contain_exactly(entry_jan)
      end
    end

    describe ".for_date" do
      let!(:entry_today) { create(:work_hour_work_entry, worked_on: Date.new(2025, 1, 15)) }
      let!(:entry_tomorrow) { create(:work_hour_work_entry, worked_on: Date.new(2025, 1, 16)) }

      it "returns entries for the specified date" do
        expect(described_class.for_date(Date.new(2025, 1, 15))).to contain_exactly(entry_today)
      end
    end

    describe ".for_period" do
      let!(:entry1) { create(:work_hour_work_entry, target_month: Date.new(2025, 1, 1)) }
      let!(:entry2) { create(:work_hour_work_entry, target_month: Date.new(2025, 2, 1)) }
      let!(:entry3) { create(:work_hour_work_entry, target_month: Date.new(2025, 3, 1)) }

      it "returns entries within the specified period" do
        expect(described_class.for_period(Date.new(2025, 1, 1), Date.new(2025, 2, 1)))
          .to contain_exactly(entry1, entry2)
      end
    end
  end

  describe "#hours" do
    it "converts minutes to hours" do
      entry = build(:work_hour_work_entry, minutes: 90)
      expect(entry.hours).to eq(1.5)
    end
  end

  describe "#project_name" do
    context "when project is present" do
      it "returns project name" do
        project = create(:work_hour_project, name: "Test Project")
        entry = build(:work_hour_work_entry, project: project)
        expect(entry.project_name).to eq("Test Project")
      end
    end

    context "when project is nil" do
      it "returns 'その他'" do
        entry = build(:work_hour_work_entry, project: nil)
        expect(entry.project_name).to eq("その他")
      end
    end
  end

  describe "#project_code" do
    context "when project is present" do
      it "returns project code" do
        project = create(:work_hour_project, code: "test-project")
        entry = build(:work_hour_work_entry, project: project)
        expect(entry.project_code).to eq("test-project")
      end
    end

    context "when project is nil" do
      it "returns empty string" do
        entry = build(:work_hour_work_entry, project: nil)
        expect(entry.project_code).to eq("")
      end
    end
  end

  describe ".total_minutes_by_project" do
    let!(:project1) { create(:work_hour_project) }
    let!(:project2) { create(:work_hour_project) }

    it "sums minutes per project" do
      create(:work_hour_work_entry, project: project1, minutes: 60)
      create(:work_hour_work_entry, project: project1, minutes: 90)
      create(:work_hour_work_entry, project: project2, minutes: 30)

      totals = described_class.total_minutes_by_project
      expect(totals[project1.id]).to eq(150)
      expect(totals[project2.id]).to eq(30)
    end

    it "returns 0 for a project without entries" do
      expect(described_class.total_minutes_by_project[project1.id]).to eq(0)
    end

    it "excludes entries without a project" do
      create(:work_hour_work_entry, project: nil, minutes: 120)

      totals = described_class.total_minutes_by_project
      expect(totals.keys).not_to include(nil)
      expect(totals.values.sum).to eq(0)
    end

    it "aggregates all projects in a single query" do
      create(:work_hour_work_entry, project: project1, minutes: 60)
      create(:work_hour_work_entry, project: project2, minutes: 60)

      expect(count_queries { described_class.total_minutes_by_project }).to eq(1)
    end
  end

  describe ".total_minutes_by_month" do
    let!(:project) { create(:work_hour_project) }
    let!(:other_project) { create(:work_hour_project) }

    it "sums minutes per target month for the given project" do
      create(:work_hour_work_entry, project: project, target_month: Date.new(2025, 1, 1), minutes: 60)
      create(:work_hour_work_entry, project: project, target_month: Date.new(2025, 1, 1), minutes: 90)
      create(:work_hour_work_entry, project: project, target_month: Date.new(2025, 2, 1), minutes: 30)

      totals = described_class.total_minutes_by_month(project)
      expect(totals[Date.new(2025, 1, 1)]).to eq(150)
      expect(totals[Date.new(2025, 2, 1)]).to eq(30)
    end

    it "excludes entries of other projects" do
      create(:work_hour_work_entry, project: other_project, target_month: Date.new(2025, 1, 1), minutes: 60)

      expect(described_class.total_minutes_by_month(project)).to be_empty
    end

    it "returns an empty result for a project without entries" do
      expect(described_class.total_minutes_by_month(project)).to be_empty
    end
  end
end
