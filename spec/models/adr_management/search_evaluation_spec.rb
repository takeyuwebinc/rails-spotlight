# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::SearchEvaluation do
  it "is valid with a factory and requires k, recall in 0..1 and origin" do
    expect(build(:adr_management_search_evaluation)).to be_valid
    expect(build(:adr_management_search_evaluation, k: nil)).not_to be_valid
    expect(build(:adr_management_search_evaluation, recall: 1.5)).not_to be_valid
    expect(build(:adr_management_search_evaluation, recall: -0.1)).not_to be_valid
    expect(build(:adr_management_search_evaluation, origin: nil)).not_to be_valid
  end
end
