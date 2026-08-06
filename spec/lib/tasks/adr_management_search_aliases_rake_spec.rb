# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "adr_management:generate_search_aliases task" do
  before do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    Rake::Task["adr_management:generate_search_aliases"].reenable
    stub_llm('{"aliases": ["ペイロード"]}')
  end

  after { ENV.delete("FORCE") }

  def stub_llm(content)
    llm = instance_double(RubyLLM::Chat)
    context = instance_double(RubyLLM::Context)
    allow(RubyLLM).to receive(:context).and_return(context)
    allow(context).to receive(:chat).and_return(llm)
    allow(llm).to receive(:ask).and_return(double(content: content))
    llm
  end

  def invoke
    Rake::Task["adr_management:generate_search_aliases"].invoke
  end

  it "generates aliases only for adrs without them" do
    pending_adr = create(:adr_management_adr, decision: "payload を検証する", search_aliases: nil)
    done_adr = create(:adr_management_adr, decision: "payload を変換する", search_aliases: "既存")

    expect { invoke }.to output(/1\/1/).to_stdout

    expect(pending_adr.reload.search_aliases).to eq("ペイロード")
    expect(done_adr.reload.search_aliases).to eq("既存")
  end

  it "skips adrs whose generation produced no alias on a re-run" do
    create(:adr_management_adr, search_aliases: "")

    expect { invoke }.to output(/対象の ADR はありません/).to_stdout
  end

  it "regenerates every adr when FORCE is set" do
    adr = create(:adr_management_adr, decision: "payload を検証する", search_aliases: "旧エイリアス")
    ENV["FORCE"] = "1"

    invoke

    expect(adr.reload.search_aliases).to eq("ペイロード")
  end
end
