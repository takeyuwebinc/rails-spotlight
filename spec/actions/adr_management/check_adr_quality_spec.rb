# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::CheckAdrQuality do
  let(:engagement) { create(:adr_management_engagement) }

  def build_adr(**overrides)
    create(:adr_management_adr, engagement: engagement, **overrides)
  end

  def perform(adr)
    described_class.perform(adr: adr, origin: "test").data
  end

  def codes(assessment)
    assessment.findings.map { |finding| finding["code"] }
  end

  # ルール5項目すべてを満たす本文
  def clean_attributes
    {
      alternatives: "### 案1: 現状維持\n遅延が解消されないため却下。\n### 案2: 別方式\n運用負荷のため却下。",
      consequences: "ポジティブ: 応答が短縮される。\nネガティブ: 実装が複雑になる。",
      reevaluation_conditions: "- 障害が月3件を超えた場合（方式の見直しを検討する）"
    }
  end

  it "records an assessment with no findings for a well-formed adr" do
    assessment = perform(build_adr(**clean_attributes))

    expect(assessment.findings).to be_empty
    expect(assessment.layer).to eq("rule")
    expect(assessment.reviewed_at).to be_present
    expect(assessment.content_fingerprint).to be_present
  end

  it "detects missing alternatives" do
    assessment = perform(build_adr(**clean_attributes, alternatives: nil))

    expect(codes(assessment)).to include("alternatives_missing")
    expect(assessment.reviewed_at).to be_nil
  end

  it "detects fewer than two alternatives and a missing status-quo option" do
    assessment = perform(build_adr(**clean_attributes, alternatives: "別方式も考えたがやめた"))

    expect(codes(assessment)).to include("alternatives_insufficient", "status_quo_missing")
  end

  it "detects consequences without negative impacts" do
    assessment = perform(build_adr(**clean_attributes, consequences: "高速になり、保守もしやすくなる"))

    expect(codes(assessment)).to include("negative_consequences_missing")
  end

  it "detects reevaluation conditions without an observable trigger or a review target" do
    assessment = perform(build_adr(**clean_attributes, reevaluation_conditions: "- 品質が低いようなら"))

    expect(codes(assessment)).to include("reevaluation_condition_format")
  end

  it "accepts absent reevaluation conditions without a finding" do
    assessment = perform(build_adr(**clean_attributes, reevaluation_conditions: nil))

    expect(codes(assessment)).not_to include("reevaluation_condition_format")
  end

  it "detects effect claims without evidence and accepts claims with evidence on the same line" do
    with_evidence = build_adr(**clean_attributes, decision: "実測で処理時間が3倍改善した方式を採用する")
    expect(codes(perform(with_evidence))).not_to include("unsupported_effect_claim")

    without_evidence = build_adr(**clean_attributes, decision: "処理時間が3倍改善する方式を採用する")
    expect(codes(perform(without_evidence))).to include("unsupported_effect_claim")
  end

  it "detects an over-long body" do
    assessment = perform(build_adr(**clean_attributes, context: "あ" * 8_001))

    expect(codes(assessment)).to include("body_too_long")
  end

  describe "re-check after an update" do
    it "closes resolved findings as addressed and remaining ones as obsolete, keeping one active assessment" do
      adr = build_adr(**clean_attributes, alternatives: nil,
        consequences: "高速になる")
      first = perform(adr)
      expect(codes(first)).to include("alternatives_missing", "negative_consequences_missing")

      adr.update!(alternatives: clean_attributes[:alternatives])
      second = perform(adr)

      first.reload
      results = first.findings.to_h { |f| [ f["code"], f["review_result"] ] }
      expect(results["alternatives_missing"]).to eq("addressed")
      expect(results["negative_consequences_missing"]).to eq("obsolete")
      expect(first.reviewed_at).to be_present

      expect(codes(second)).to eq([ "negative_consequences_missing" ])
      expect(second.reviewed_at).to be_nil
    end
  end
end
