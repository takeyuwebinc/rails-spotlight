# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::AdrReference, type: :model do
  let(:source) { create(:adr_management_adr) }
  let(:target) { create(:adr_management_adr) }

  it "is unique per source and target pair" do
    described_class.create!(source_adr: source, target_adr: target)
    duplicate = described_class.new(source_adr: source, target_adr: target)

    expect(duplicate).not_to be_valid
  end

  it "allows the reverse direction as a distinct reference" do
    described_class.create!(source_adr: source, target_adr: target)
    reverse = described_class.new(source_adr: target, target_adr: source)

    expect(reverse).to be_valid
  end
end
