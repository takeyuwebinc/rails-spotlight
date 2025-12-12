# frozen_string_literal: true

require "rails_helper"

RSpec.describe "WorkHour Entry Tools" do
  let(:server_context) { {} }

  describe Tools::ListWorkHourEntriesTool do
    let!(:client) { create(:work_hour_client, code: "abc-corp") }
    let!(:project) { create(:work_hour_project, code: "project-a", name: "プロジェクトA", client: client) }
    let!(:entry1) { create(:work_hour_work_entry, project: project, worked_on: Date.new(2024, 12, 10), target_month: Date.new(2024, 12, 1), description: "開発作業", minutes: 120) }
    let!(:entry2) { create(:work_hour_work_entry, project: project, worked_on: Date.new(2024, 12, 11), target_month: Date.new(2024, 12, 1), description: "レビュー", minutes: 60) }
    let!(:entry3) { create(:work_hour_work_entry, project: project, worked_on: Date.new(2025, 1, 5), target_month: Date.new(2025, 1, 1), description: "ミーティング", minutes: 30) }

    describe ".call" do
      context "when listing all entries" do
        it "returns all entries" do
          response = described_class.call(server_context: server_context)

          expect(response.content.first[:text]).to include("Found 3 entries")
          expect(response.content.first[:text]).to include("project-a")
        end
      end

      context "when filtering by project_code" do
        let!(:other_project) { create(:work_hour_project, code: "project-b") }
        let!(:other_entry) { create(:work_hour_work_entry, project: other_project, worked_on: Date.new(2024, 12, 12)) }

        it "returns only entries for the specified project" do
          response = described_class.call(project_code: "project-a", server_context: server_context)

          expect(response.content.first[:text]).to include("project-a")
          expect(response.content.first[:text]).not_to include("project-b")
        end
      end

      context "when filtering by target_month" do
        it "returns only entries for the specified month" do
          response = described_class.call(target_month: "2024-12", server_context: server_context)

          expect(response.content.first[:text]).to include("Found 2 entries")
          expect(response.content.first[:text]).to include("2024-12-10")
          expect(response.content.first[:text]).to include("2024-12-11")
          expect(response.content.first[:text]).not_to include("2025-01-05")
        end
      end

      context "when filtering by date range" do
        it "returns entries within the range" do
          response = described_class.call(start_date: "2024-12-10", end_date: "2024-12-11", server_context: server_context)

          expect(response.content.first[:text]).to include("Found 2 entries")
        end
      end

      context "when no entries exist" do
        before { WorkHour::WorkEntry.destroy_all }

        it "returns no entries message" do
          response = described_class.call(server_context: server_context)

          expect(response.content.first[:text]).to include("No entries found")
        end
      end

      it "includes total time" do
        response = described_class.call(target_month: "2024-12", server_context: server_context)

        # 120 + 60 = 180 minutes = 3h 0m
        expect(response.content.first[:text]).to include("Total:")
        expect(response.content.first[:text]).to include("3h")
      end
    end
  end

  describe Tools::CreateWorkHourEntryTool do
    let!(:client) { create(:work_hour_client, code: "abc-corp") }
    let!(:project) { create(:work_hour_project, code: "abc-system", name: "ABC基幹システム", client: client) }

    describe ".call" do
      context "with valid params and project_code" do
        it "creates a new entry" do
          expect {
            described_class.call(
              project_code: "abc-system",
              worked_on: "2024-12-15",
              minutes: 120,
              description: "開発作業",
              server_context: server_context
            )
          }.to change(WorkHour::WorkEntry, :count).by(1)
        end

        it "returns success message" do
          response = described_class.call(
            project_code: "abc-system",
            worked_on: "2024-12-15",
            minutes: 120,
            description: "開発作業",
            server_context: server_context
          )

          expect(response.content.first[:text]).to include("Work entry created successfully")
          expect(response.content.first[:text]).to include("Date: 2024-12-15")
          expect(response.content.first[:text]).to include("Project: ABC基幹システム")
          expect(response.content.first[:text]).to include("Description: 開発作業")
          expect(response.content.first[:text]).to include("Time: 2h 0m")
        end
      end

      context "without project_code (その他)" do
        it "creates an entry without project" do
          response = described_class.call(
            worked_on: "2024-12-15",
            minutes: 30,
            description: "雑務",
            server_context: server_context
          )

          expect(response.content.first[:text]).to include("Work entry created successfully")
          expect(response.content.first[:text]).to include("Project: その他")
          entry = WorkHour::WorkEntry.last
          expect(entry.project).to be_nil
        end
      end

      context "with target_month specified" do
        it "uses the specified target_month" do
          described_class.call(
            project_code: "abc-system",
            worked_on: "2024-12-31",
            target_month: "2025-01",
            minutes: 60,
            server_context: server_context
          )

          entry = WorkHour::WorkEntry.last
          expect(entry.target_month).to eq(Date.new(2025, 1, 1))
        end
      end

      context "without target_month (defaults to worked_on month)" do
        it "uses worked_on month as target_month" do
          described_class.call(
            project_code: "abc-system",
            worked_on: "2024-12-15",
            minutes: 60,
            server_context: server_context
          )

          entry = WorkHour::WorkEntry.last
          expect(entry.target_month).to eq(Date.new(2024, 12, 1))
        end
      end

      context "when project_code not found" do
        it "returns error message" do
          response = described_class.call(
            project_code: "nonexistent",
            worked_on: "2024-12-15",
            minutes: 60,
            server_context: server_context
          )

          expect(response.content.first[:text]).to include("Error")
          expect(response.content.first[:text]).to include("not found")
        end
      end

      context "with invalid minutes" do
        it "returns error for zero minutes" do
          response = described_class.call(
            project_code: "abc-system",
            worked_on: "2024-12-15",
            minutes: 0,
            server_context: server_context
          )

          expect(response.content.first[:text]).to include("Error")
        end

        it "returns error for negative minutes" do
          response = described_class.call(
            project_code: "abc-system",
            worked_on: "2024-12-15",
            minutes: -30,
            server_context: server_context
          )

          expect(response.content.first[:text]).to include("Error")
        end
      end
    end
  end
end
