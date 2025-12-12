# frozen_string_literal: true

require "rails_helper"

RSpec.describe "WorkHour Project Tools" do
  let(:server_context) { {} }

  describe Tools::ListWorkHourProjectsTool do
    describe ".call" do
      let!(:client) { create(:work_hour_client, code: "abc-corp", name: "ABC商事") }
      let!(:project1) { create(:work_hour_project, code: "abc-system", name: "ABC基幹システム", client: client, status: :active) }
      let!(:project2) { create(:work_hour_project, code: "xyz-app", name: "XYZアプリ", client: client, status: :closed) }

      context "when listing all projects" do
        it "returns all projects" do
          response = described_class.call(server_context: server_context)

          expect(response.content.first[:text]).to include("Found 2 project(s)")
          expect(response.content.first[:text]).to include("abc-system")
          expect(response.content.first[:text]).to include("xyz-app")
        end
      end

      context "when filtering by active status" do
        it "returns only active projects" do
          response = described_class.call(status: "active", server_context: server_context)

          expect(response.content.first[:text]).to include("Found 1 project(s)")
          expect(response.content.first[:text]).to include("abc-system")
          expect(response.content.first[:text]).not_to include("xyz-app")
        end
      end

      context "when filtering by closed status" do
        it "returns only closed projects" do
          response = described_class.call(status: "closed", server_context: server_context)

          expect(response.content.first[:text]).to include("Found 1 project(s)")
          expect(response.content.first[:text]).to include("xyz-app")
          expect(response.content.first[:text]).not_to include("abc-system")
        end
      end

      context "when filtering by client_code" do
        let!(:other_client) { create(:work_hour_client, code: "other-corp") }
        let!(:other_project) { create(:work_hour_project, code: "other-project", client: other_client) }

        it "returns only projects for the specified client" do
          response = described_class.call(client_code: "abc-corp", server_context: server_context)

          expect(response.content.first[:text]).to include("abc-system")
          expect(response.content.first[:text]).not_to include("other-project")
        end
      end

      context "when no projects exist" do
        before { WorkHour::Project.destroy_all }

        it "returns no projects message" do
          response = described_class.call(server_context: server_context)

          expect(response.content.first[:text]).to include("No projects found")
        end
      end
    end
  end

  describe Tools::FindWorkHourProjectTool do
    let!(:client) { create(:work_hour_client, code: "abc-corp", name: "ABC商事") }
    let!(:project) { create(:work_hour_project, code: "abc-system", name: "ABC基幹システム", client: client) }

    context "when project found by exact code match" do
      it "returns project with details" do
        response = described_class.call(query: "abc-system", server_context: server_context)

        expect(response.content.first[:text]).to include("Found project")
        expect(response.content.first[:text]).to include("Code: abc-system")
        expect(response.content.first[:text]).to include("Name: ABC基幹システム")
        expect(response.content.first[:text]).to include("Client: ABC商事")
      end
    end

    context "when project found by partial code match" do
      it "returns project" do
        response = described_class.call(query: "abc", server_context: server_context)

        expect(response.content.first[:text]).to include("Found project")
        expect(response.content.first[:text]).to include("abc-system")
      end
    end

    context "when project found by name match" do
      it "returns project" do
        response = described_class.call(query: "基幹システム", server_context: server_context)

        expect(response.content.first[:text]).to include("Found project")
        expect(response.content.first[:text]).to include("ABC基幹システム")
      end
    end

    context "when project not found" do
      it "returns not found message" do
        response = described_class.call(query: "nonexistent", server_context: server_context)

        expect(response.content.first[:text]).to include("Project not found")
      end
    end

    context "with monthly estimates" do
      let!(:estimate) { create(:work_hour_project_monthly_estimate, project: project, year_month: Date.today.beginning_of_month, estimated_hours: 40) }

      it "includes monthly estimates in output" do
        response = described_class.call(query: "abc-system", server_context: server_context)

        expect(response.content.first[:text]).to include("40")
      end
    end
  end

  describe Tools::CreateWorkHourProjectTool do
    let!(:client) { create(:work_hour_client, code: "abc-corp", name: "ABC商事") }

    describe ".call" do
      context "with valid params and client_code" do
        it "creates a new project" do
          expect {
            described_class.call(
              code: "new-project",
              name: "新規プロジェクト",
              client_code: "abc-corp",
              server_context: server_context
            )
          }.to change(WorkHour::Project, :count).by(1)
        end

        it "returns success message" do
          response = described_class.call(
            code: "new-project",
            name: "新規プロジェクト",
            client_code: "abc-corp",
            server_context: server_context
          )

          expect(response.content.first[:text]).to include("Project created successfully")
          expect(response.content.first[:text]).to include("Code: new-project")
          expect(response.content.first[:text]).to include("Name: 新規プロジェクト")
          expect(response.content.first[:text]).to include("Client: ABC商事")
          expect(response.content.first[:text]).to include("Status: active")
        end
      end

      context "without client_code" do
        it "creates a project without client" do
          response = described_class.call(
            code: "standalone-project",
            name: "スタンドアロンプロジェクト",
            server_context: server_context
          )

          expect(response.content.first[:text]).to include("Project created successfully")
          project = WorkHour::Project.find_by(code: "standalone-project")
          expect(project.client).to be_nil
        end
      end

      context "with custom color" do
        it "uses the specified color" do
          described_class.call(
            code: "colored-project",
            name: "カラープロジェクト",
            color: "#ff0000",
            server_context: server_context
          )

          project = WorkHour::Project.find_by(code: "colored-project")
          expect(project.color).to eq("#ff0000")
        end
      end

      context "with dates" do
        it "sets start and end dates" do
          described_class.call(
            code: "dated-project",
            name: "日付付きプロジェクト",
            start_date: "2024-01-01",
            end_date: "2024-12-31",
            server_context: server_context
          )

          project = WorkHour::Project.find_by(code: "dated-project")
          expect(project.start_date).to eq(Date.parse("2024-01-01"))
          expect(project.end_date).to eq(Date.parse("2024-12-31"))
        end
      end

      context "when code already exists" do
        let!(:existing) { create(:work_hour_project, code: "existing-code") }

        it "returns error message" do
          response = described_class.call(
            code: "existing-code",
            name: "重複プロジェクト",
            server_context: server_context
          )

          expect(response.content.first[:text]).to include("Error")
          expect(response.content.first[:text]).to include("already exists")
        end

        it "does not create project" do
          expect {
            described_class.call(
              code: "existing-code",
              name: "重複プロジェクト",
              server_context: server_context
            )
          }.not_to change(WorkHour::Project, :count)
        end
      end

      context "when client_code not found" do
        it "returns error message" do
          response = described_class.call(
            code: "new-project",
            name: "新規プロジェクト",
            client_code: "nonexistent-client",
            server_context: server_context
          )

          expect(response.content.first[:text]).to include("Error")
          expect(response.content.first[:text]).to include("not found")
        end
      end

      context "with missing required params" do
        it "returns error for missing code" do
          response = described_class.call(
            code: "",
            name: "名前のみ",
            server_context: server_context
          )

          expect(response.content.first[:text]).to include("Error")
        end
      end
    end
  end
end
