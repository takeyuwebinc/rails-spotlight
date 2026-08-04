# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::GoldenQuery do
  it "is valid with a factory and requires query and origin" do
    expect(build(:adr_management_golden_query)).to be_valid
    expect(build(:adr_management_golden_query, query: nil)).not_to be_valid
    expect(build(:adr_management_golden_query, origin: nil)).not_to be_valid
  end

  it "is destroyed together with its ADR" do
    golden_query = create(:adr_management_golden_query)

    expect { golden_query.adr.destroy! }.to change(described_class, :count).by(-1)
  end
end
