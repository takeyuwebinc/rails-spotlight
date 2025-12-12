# frozen_string_literal: true

require "rails_helper"

RSpec.describe "WorkHour Estimate Tools" do
  let(:server_context) { {} }

  describe Tools::ListWorkHourEstimatesTool do
    let!(:client) { create(:work_hour_client, code: "abc-corp") }
    let!(:project1) { create(:work_hour_project, code: "project-a", name: "プロジェクトA", client: client) }
    let!(:project2) { create(:work_hour_project, code: "project-b", name: "プロジェクトB", client: client) }
    let!(:estimate1) { create(:work_hour_project_monthly_estimate, project: project1, year_month: Date.new(2024, 12, 1), estimated_hours: 40) }
    let!(:estimate2) { create(:work_hour_project_monthly_estimate, project: project1, year_month: Date.new(2025, 1, 1), estimated_hours: 60) }
    let!(:estimate3) { create(:work_hour_project_monthly_estimate, project: project2, year_month: Date.new(2024, 12, 1), estimated_hours: 20) }

    describe ".call" do
      context "when listing all estimates" do
        it "returns all estimates" do
          response = described_class.call(server_context: server_context)

          expect(response.content.first[:text]).to include("Found 3 estimate(s)")
          expect(response.content.first[:text]).to include("project-a")
          expect(response.content.first[:text]).to include("project-b")
        end
      end

      context "when filtering by project_code" do
        it "returns only estimates for the specified project" do
          response = described_class.call(project_code: "project-a", server_context: server_context)

          expect(response.content.first[:text]).to include("Found 2 estimate(s)")
          expect(response.content.first[:text]).to include("project-a")
          expect(response.content.first[:text]).not_to include("project-b")
        end
      end

      context "when filtering by year_month" do
        it "returns only estimates for the specified month" do
          response = described_class.call(year_month: "2024-12", server_context: server_context)

          expect(response.content.first[:text]).to include("Found 2 estimate(s)")
          expect(response.content.first[:text]).to include("2024-12")
          expect(response.content.first[:text]).not_to include("2025-01")
        end
      end

      context "when filtering by month range" do
        it "returns estimates within the range" do
          response = described_class.call(from_month: "2024-12", to_month: "2025-01", server_context: server_context)

          expect(response.content.first[:text]).to include("Found 3 estimate(s)")
        end
      end

      context "when no estimates exist" do
        before { WorkHour::ProjectMonthlyEstimate.destroy_all }

        it "returns no estimates message" do
          response = described_class.call(server_context: server_context)

          expect(response.content.first[:text]).to include("No estimates found")
        end
      end
    end
  end

  describe Tools::CreateWorkHourEstimateTool do
    let!(:client) { create(:work_hour_client, code: "abc-corp") }
    let!(:project) { create(:work_hour_project, code: "abc-system", name: "ABC基幹システム", client: client) }

    describe ".call" do
      context "with valid params" do
        it "creates a new estimate" do
          expect {
            described_class.call(
              project_code: "abc-system",
              year_month: "2025-01",
              estimated_hours: 80,
              server_context: server_context
            )
          }.to change(WorkHour::ProjectMonthlyEstimate, :count).by(1)
        end

        it "returns success message" do
          response = described_class.call(
            project_code: "abc-system",
            year_month: "2025-01",
            estimated_hours: 80,
            server_context: server_context
          )

          expect(response.content.first[:text]).to include("Estimate created successfully")
          expect(response.content.first[:text]).to include("Project: ABC基幹システム (abc-system)")
          expect(response.content.first[:text]).to include("Month: 2025-01")
          expect(response.content.first[:text]).to include("Hours: 80h")
        end
      end

      context "when project_code not found" do
        it "returns error message" do
          response = described_class.call(
            project_code: "nonexistent",
            year_month: "2025-01",
            estimated_hours: 80,
            server_context: server_context
          )

          expect(response.content.first[:text]).to include("Error")
          expect(response.content.first[:text]).to include("not found")
        end

        it "does not create estimate" do
          expect {
            described_class.call(
              project_code: "nonexistent",
              year_month: "2025-01",
              estimated_hours: 80,
              server_context: server_context
            )
          }.not_to change(WorkHour::ProjectMonthlyEstimate, :count)
        end
      end

      context "when estimate already exists for same project and month" do
        let!(:existing) { create(:work_hour_project_monthly_estimate, project: project, year_month: Date.new(2025, 1, 1), estimated_hours: 40) }

        it "returns error message" do
          response = described_class.call(
            project_code: "abc-system",
            year_month: "2025-01",
            estimated_hours: 80,
            server_context: server_context
          )

          expect(response.content.first[:text]).to include("Error")
          expect(response.content.first[:text]).to include("already exists")
        end

        it "does not create duplicate estimate" do
          expect {
            described_class.call(
              project_code: "abc-system",
              year_month: "2025-01",
              estimated_hours: 80,
              server_context: server_context
            )
          }.not_to change(WorkHour::ProjectMonthlyEstimate, :count)
        end
      end

      context "with invalid estimated_hours" do
        it "returns error for negative hours" do
          response = described_class.call(
            project_code: "abc-system",
            year_month: "2025-01",
            estimated_hours: -10,
            server_context: server_context
          )

          expect(response.content.first[:text]).to include("Error")
        end
      end
    end
  end
end
