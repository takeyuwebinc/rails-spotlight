# frozen_string_literal: true

require "rails_helper"

RSpec.describe "WorkHour Client Tools" do
  let(:server_context) { {} }

  describe Tools::ListWorkHourClientsTool do
    describe ".call" do
      context "when clients exist" do
        let!(:client1) { create(:work_hour_client, code: "abc-corp", name: "ABC商事") }
        let!(:client2) { create(:work_hour_client, code: "xyz-inc", name: "XYZ株式会社") }
        let!(:project) { create(:work_hour_project, client: client1) }

        it "returns all clients with project counts" do
          response = described_class.call(server_context: server_context)

          expect(response.content.first[:text]).to include("Found 2 client(s)")
          expect(response.content.first[:text]).to include("abc-corp")
          expect(response.content.first[:text]).to include("ABC商事")
          expect(response.content.first[:text]).to include("projects: 1")
          expect(response.content.first[:text]).to include("xyz-inc")
        end
      end

      context "when no clients exist" do
        it "returns no clients message" do
          response = described_class.call(server_context: server_context)

          expect(response.content.first[:text]).to include("No clients found")
        end
      end
    end
  end

  describe Tools::FindWorkHourClientTool do
    describe ".call" do
      let!(:client) { create(:work_hour_client, code: "abc-corp", name: "ABC商事") }
      let!(:project) { create(:work_hour_project, code: "abc-system", name: "ABC基幹システム", client: client) }

      context "when client found by exact code match" do
        it "returns client with projects" do
          response = described_class.call(query: "abc-corp", server_context: server_context)

          expect(response.content.first[:text]).to include("Found client")
          expect(response.content.first[:text]).to include("Code: abc-corp")
          expect(response.content.first[:text]).to include("Name: ABC商事")
          expect(response.content.first[:text]).to include("abc-system")
        end
      end

      context "when client found by partial code match" do
        it "returns client" do
          response = described_class.call(query: "abc", server_context: server_context)

          expect(response.content.first[:text]).to include("Found client")
          expect(response.content.first[:text]).to include("abc-corp")
        end
      end

      context "when client found by name match" do
        it "returns client" do
          response = described_class.call(query: "ABC商事", server_context: server_context)

          expect(response.content.first[:text]).to include("Found client")
          expect(response.content.first[:text]).to include("ABC商事")
        end
      end

      context "when client not found" do
        it "returns not found message" do
          response = described_class.call(query: "nonexistent", server_context: server_context)

          expect(response.content.first[:text]).to include("Client not found")
        end
      end
    end
  end

  describe Tools::CreateWorkHourClientTool do
    describe ".call" do
      context "with valid params" do
        it "creates a new client" do
          expect {
            described_class.call(
              code: "new-client",
              name: "新規クライアント",
              server_context: server_context
            )
          }.to change(WorkHour::Client, :count).by(1)
        end

        it "returns success message" do
          response = described_class.call(
            code: "new-client",
            name: "新規クライアント",
            server_context: server_context
          )

          expect(response.content.first[:text]).to include("Client created successfully")
          expect(response.content.first[:text]).to include("Code: new-client")
          expect(response.content.first[:text]).to include("Name: 新規クライアント")
        end
      end

      context "when code already exists" do
        let!(:existing) { create(:work_hour_client, code: "existing-code") }

        it "returns error message" do
          response = described_class.call(
            code: "existing-code",
            name: "重複クライアント",
            server_context: server_context
          )

          expect(response.content.first[:text]).to include("Error")
          expect(response.content.first[:text]).to include("already exists")
        end

        it "does not create client" do
          expect {
            described_class.call(
              code: "existing-code",
              name: "重複クライアント",
              server_context: server_context
            )
          }.not_to change(WorkHour::Client, :count)
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
