# frozen_string_literal: true

require "rails_helper"

RSpec.describe Client, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      client = build(:client)
      expect(client).to be_valid
    end

    it "is invalid without code" do
      client = build(:client, code: nil)
      expect(client).not_to be_valid
      expect(client.errors[:code]).to include("can't be blank")
    end

    it "is invalid without name" do
      client = build(:client, name: nil)
      expect(client).not_to be_valid
      expect(client.errors[:name]).to include("can't be blank")
    end

    it "is invalid with duplicate code" do
      create(:client, code: "shared-code")
      client = build(:client, code: "shared-code")
      expect(client).not_to be_valid
      expect(client.errors[:code]).to include("has already been taken")
    end
  end
end
