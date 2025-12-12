# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkHour::Client, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      client = build(:work_hour_client)
      expect(client).to be_valid
    end

    it "is invalid without code" do
      client = build(:work_hour_client, code: nil)
      expect(client).not_to be_valid
      expect(client.errors[:code]).to include("can't be blank")
    end

    it "is invalid without name" do
      client = build(:work_hour_client, name: nil)
      expect(client).not_to be_valid
      expect(client.errors[:name]).to include("can't be blank")
    end

    it "is invalid with duplicate code" do
      create(:work_hour_client, code: "test-code")
      client = build(:work_hour_client, code: "test-code")
      expect(client).not_to be_valid
      expect(client.errors[:code]).to include("has already been taken")
    end
  end

  describe "associations" do
    it "has many projects" do
      client = create(:work_hour_client)
      project = create(:work_hour_project, client: client)
      expect(client.projects).to include(project)
    end

    it "nullifies projects when destroyed" do
      client = create(:work_hour_client)
      project = create(:work_hour_project, client: client)
      client.destroy
      expect(project.reload.client_id).to be_nil
    end
  end

  describe ".generate_code_from_name" do
    it "generates a code from English name" do
      expect(described_class.generate_code_from_name("ACME Corp")).to eq("acme-corp")
    end

    it "handles special characters" do
      expect(described_class.generate_code_from_name("ABC & XYZ")).to eq("abc-xyz")
    end

    it "handles empty string" do
      expect(described_class.generate_code_from_name("")).to eq("")
    end

    it "removes Japanese characters (non-ascii)" do
      expect(described_class.generate_code_from_name("ABC商事")).to eq("abc")
    end
  end
end
