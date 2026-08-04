# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdrManagement::SyncAdrReferences do
  let(:engagement) { create(:adr_management_engagement, code: "spotlight-rails") }
  let!(:target) { create(:adr_management_adr, engagement: engagement) }
  let(:adr) { create(:adr_management_adr, engagement: engagement) }

  def sync
    described_class.perform(adr: adr)
  end

  it "records references resolved from body fields" do
    adr.update!(context: "SPOTLIGHT-RAILS-#{target.number} の決定を前提とする")

    result = sync
    expect(result.success?).to be(true)
    expect(adr.referenced_adrs.reload).to eq([ target ])
    expect(result.data.referenced_adrs).to eq([ target ])
  end

  it "extracts from all body fields" do
    adr.update!(reevaluation_conditions: "SPOTLIGHT-RAILS-#{target.number} が置換されたら見直す")

    sync
    expect(adr.referenced_adrs.reload).to eq([ target ])
  end

  it "removes references whose tokens disappeared from the body" do
    adr.update!(context: "SPOTLIGHT-RAILS-#{target.number} を参照")
    sync

    adr.update!(context: "参照なし")
    sync
    expect(adr.referenced_adrs.reload).to be_empty
  end

  it "does not record self references" do
    adr.update!(context: "自身は #{adr.display_number} である")

    sync
    expect(adr.referenced_adrs.reload).to be_empty
  end

  it "records each target once even when referenced multiple times" do
    adr.update!(
      context: "SPOTLIGHT-RAILS-#{target.number} を参照",
      decision: "spotlight-rails-#{target.number} に従う"
    )

    sync
    expect(adr.referenced_adrs.reload).to eq([ target ])
  end

  it "reports unknown numbers for existing codes without recording references" do
    adr.update!(context: "SPOTLIGHT-RAILS-9999 を参照")

    result = sync
    expect(result.data.unknown_numbers).to eq([ "SPOTLIGHT-RAILS-9999" ])
    expect(adr.referenced_adrs.reload).to be_empty
  end

  it "ignores tokens whose engagement code does not exist" do
    adr.update!(context: "UTF-8 でエンコードする")

    result = sync
    expect(result.data.unknown_numbers).to be_empty
    expect(adr.referenced_adrs.reload).to be_empty
  end
end
