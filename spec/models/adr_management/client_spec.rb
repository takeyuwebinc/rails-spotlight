# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::Client, type: :model do
  describe "shared client integration" do
    it "creates a shared client on create" do
      client = create(:adr_management_client, code: "acme", name: "ACME商事")
      expect(Client.find_by(code: "acme")).to be_present
      expect(client.code).to eq("acme")
      expect(client.name).to eq("ACME商事")
    end

    it "attaches to an existing shared client with the same code" do
      shared = create(:client, code: "acme", name: "ACME商事")
      client = create(:adr_management_client, code: "acme", name: "ACME商事")
      expect(client.shared_client).to eq(shared)
    end

    it "shares the same entity with a work hour client via code" do
      work_hour_client = create(:work_hour_client, code: "acme", name: "ACME商事")
      adr_client = create(:adr_management_client, code: "acme", name: "ACME商事")
      expect(adr_client.shared_client).to eq(work_hour_client.shared_client)
    end

    it "is invalid when the shared client already has an adr management extension" do
      create(:adr_management_client, code: "acme")
      duplicated = build(:adr_management_client, code: "acme")
      expect(duplicated).not_to be_valid
      expect(duplicated.errors[:code]).to include("has already been taken")
    end

    it "is invalid without code" do
      client = build(:adr_management_client, code: nil)
      expect(client).not_to be_valid
      expect(client.errors[:code]).to include("can't be blank")
    end

    it "keeps the shared client when the extension is destroyed" do
      client = create(:adr_management_client, code: "acme")
      expect { client.destroy }.not_to change(Client, :count)
    end
  end

  describe "engagements" do
    it "cannot be destroyed when engagements exist" do
      client = create(:adr_management_client)
      create(:adr_management_engagement, client: client)
      expect(client.destroy).to be_falsey
      expect(client.errors[:base]).to be_present
    end
  end
end
