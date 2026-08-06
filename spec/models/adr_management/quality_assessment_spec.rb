# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::QualityAssessment do
  describe "validations" do
    it "requires layer to be rule or llm" do
      assessment = build(:adr_management_quality_assessment, layer: "manual")
      expect(assessment).not_to be_valid
    end

    it "rejects findings that are not an array of code/message hashes" do
      assessment = build(:adr_management_quality_assessment, findings: [ { "code" => "x" } ])
      expect(assessment).not_to be_valid
    end

    it "rejects findings with an unknown review_result" do
      assessment = build(:adr_management_quality_assessment, findings: [
        { "code" => "x", "message" => "m", "review_result" => "ignored" }
      ])
      expect(assessment).not_to be_valid
    end

    it "accepts an empty findings array" do
      assessment = build(:adr_management_quality_assessment, findings: [])
      expect(assessment).to be_valid
    end
  end

  describe ".fingerprint_for" do
    it "changes when a quality source attribute changes and ignores other attributes" do
      adr = create(:adr_management_adr)
      original = described_class.fingerprint_for(adr)

      adr.reference_links = "https://example.com"
      expect(described_class.fingerprint_for(adr)).to eq(original)

      adr.decision = "別の決定"
      expect(described_class.fingerprint_for(adr)).not_to eq(original)
    end
  end

  describe "#close_open_findings!" do
    let(:assessment) do
      create(:adr_management_quality_assessment, findings: [
        { "code" => "a", "field" => "f", "message" => "m1" },
        { "code" => "b", "field" => "f", "message" => "m2" }
      ])
    end

    it "resolves only the given codes and keeps the assessment pending" do
      assessment.close_open_findings!(result: "addressed", only_codes: [ "a" ])

      results = assessment.findings.to_h { |f| [ f["code"], f["review_result"] ] }
      expect(results).to eq("a" => "addressed", "b" => nil)
      expect(assessment.reviewed_at).to be_nil
    end

    it "sets reviewed_at once all findings are resolved" do
      assessment.close_open_findings!(result: "obsolete")

      expect(assessment.open_findings).to be_empty
      expect(assessment.reviewed_at).to be_present
    end

    it "rejects results outside FINDING_RESULTS" do
      expect { assessment.close_open_findings!(result: "ignored") }.to raise_error(ArgumentError)
    end
  end

  describe "auto-close on ADR retirement" do
    it "closes open findings as obsolete when the adr is deprecated" do
      adr = create(:adr_management_adr, status: "accepted")
      assessment = create(:adr_management_quality_assessment, adr: adr)

      adr.update!(status: "deprecated")

      assessment.reload
      expect(assessment.open_findings).to be_empty
      expect(assessment.findings.first["review_result"]).to eq("obsolete")
    end

    it "keeps findings open on a content-only update" do
      adr = create(:adr_management_adr, status: "accepted")
      assessment = create(:adr_management_quality_assessment, adr: adr)

      adr.update!(title: "新しいタイトル")

      expect(assessment.reload.open_findings).not_to be_empty
    end
  end
end
