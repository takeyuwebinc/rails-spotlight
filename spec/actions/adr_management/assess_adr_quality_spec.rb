# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::AssessAdrQuality do
  let(:adr) { create(:adr_management_adr) }

  def stub_llm(content)
    llm = instance_double(RubyLLM::Chat)
    context = instance_double(RubyLLM::Context)
    allow(RubyLLM).to receive(:context).and_return(context)
    allow(context).to receive(:chat).and_return(llm)
    allow(llm).to receive(:ask).and_return(double(content: content))
    llm
  end

  def perform
    described_class.perform(adr: adr, origin: "system:test").data
  end

  it "records llm findings from the model response" do
    stub_llm(<<~JSON)
      ```json
      {"findings": [{"code": "generic_knowledge", "field": "decision",
        "message": "一般的なベストプラクティスの再掲に見えます"}]}
      ```
    JSON

    assessment = perform

    expect(assessment.layer).to eq("llm")
    expect(assessment.findings.sole["code"]).to eq("generic_knowledge")
    expect(assessment.reviewed_at).to be_nil
  end

  it "records a zero-finding assessment as reviewed" do
    stub_llm('{"findings": []}')

    assessment = perform

    expect(assessment.findings).to be_empty
    expect(assessment.reviewed_at).to be_present
  end

  it "discards findings with unknown codes or missing messages" do
    stub_llm('{"findings": [{"code": "made_up", "message": "x"}, {"code": "generic_knowledge"}]}')

    expect(perform.findings).to be_empty
  end

  it "skips evaluation when an assessment for the same content already exists" do
    llm = stub_llm('{"findings": []}')
    first = perform

    expect(perform).to eq(first)
    expect(llm).to have_received(:ask).once
  end

  it "re-evaluates after a body change and closes previous open llm findings as obsolete" do
    stub_llm('{"findings": [{"code": "generic_knowledge", "field": "decision", "message": "一般論です"}]}')
    first = perform

    adr.update!(decision: "固有の制約に基づく別の決定")
    stub_llm('{"findings": []}')
    second = perform

    expect(second).not_to eq(first)
    first.reload
    expect(first.open_findings).to be_empty
    expect(first.findings.sole["review_result"]).to eq("obsolete")
  end

  it "skips retired adrs without calling the llm" do
    adr.update!(status: "deprecated")
    llm = stub_llm('{"findings": []}')

    expect(perform).to be_nil
    expect(llm).not_to have_received(:ask)
  end

  it "degrades to no assessment and reports when the llm call fails" do
    llm = stub_llm("")
    allow(llm).to receive(:ask).and_raise(RubyLLM::Error.allocate)
    allow(Rails.error).to receive(:report)

    expect(perform).to be_nil
    expect(adr.quality_assessments.llm_layer).to be_empty
    expect(Rails.error).to have_received(:report)
  end

  it "degrades when the response contains no json" do
    stub_llm("すみません、評価できませんでした")
    allow(Rails.error).to receive(:report)

    expect(perform).to be_nil
    expect(Rails.error).to have_received(:report)
  end
end
