# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::GenerateSearchAliases do
  let(:adr) { create(:adr_management_adr, decision: "payload の検証は JSON Schema で行う") }

  def stub_llm(content)
    llm = instance_double(RubyLLM::Chat)
    context = instance_double(RubyLLM::Context)
    allow(RubyLLM).to receive(:context).and_return(context)
    allow(context).to receive(:chat).and_return(llm)
    allow(llm).to receive(:ask).and_return(double(content: content))
    llm
  end

  def perform
    described_class.perform(adr: adr).data
  end

  it "stores aliases that do not appear in the body" do
    stub_llm('{"aliases": ["ペイロード", "ジェイソンスキーマ"]}')

    expect(perform.search_aliases).to eq("ペイロード\nジェイソンスキーマ")
  end

  it "drops aliases that already appear in the body regardless of case" do
    stub_llm('{"aliases": ["ペイロード", "PAYLOAD", "JSON Schema"]}')

    expect(perform.search_aliases).to eq("ペイロード")
  end

  it "stores an empty string when no alias is generated" do
    stub_llm('{"aliases": []}')

    expect(perform.search_aliases).to eq("")
  end

  it "truncates the generated aliases to the maximum count" do
    aliases = Array.new(described_class::MAX_ALIASES + 5) { |index| "エイリアス#{index}" }
    stub_llm({ aliases: aliases }.to_json)

    expect(perform.search_aliases.lines.size).to eq(described_class::MAX_ALIASES)
  end

  it "discards blank and duplicated entries" do
    stub_llm('{"aliases": ["ペイロード", " ", "ペイロード", "スキーマ"]}')

    expect(perform.search_aliases).to eq("ペイロード\nスキーマ")
  end

  it "does not record a revision for the generated aliases" do
    stub_llm('{"aliases": ["ペイロード"]}')

    expect { perform }.not_to change { adr.revisions.count }
  end

  it "keeps the existing aliases and reports when the llm call fails" do
    adr.update_column(:search_aliases, "既存エイリアス")
    llm = stub_llm("")
    allow(llm).to receive(:ask).and_raise(RubyLLM::Error.allocate)
    allow(Rails.error).to receive(:report)

    expect(perform).to be_nil
    expect(adr.reload.search_aliases).to eq("既存エイリアス")
    expect(Rails.error).to have_received(:report)
  end

  it "degrades when the response contains no json" do
    stub_llm("すみません、生成できませんでした")
    allow(Rails.error).to receive(:report)

    expect(perform).to be_nil
    expect(adr.reload.search_aliases).to be_nil
    expect(Rails.error).to have_received(:report)
  end

  it "skips retired adrs without calling the llm" do
    adr.update!(status: "deprecated")
    llm = stub_llm('{"aliases": ["ペイロード"]}')

    expect(perform).to be_nil
    expect(llm).not_to have_received(:ask)
  end
end
