# frozen_string_literal: true

require "rails_helper"

RSpec.describe "AdrManagement Search Tools" do
  let(:server_context) { { origin: "oauth:Test Agent" } }
  let(:endpoint) { Sakura::EmbeddingClient::ENDPOINT.to_s }

  def response_text(response)
    response.content.first[:text]
  end

  def index_adr(adr, vector)
    chunk = adr.chunks.create!(kind: "decision", content: adr.decision, state: "fresh")
    chunk.update!(embedding: vector.pack("f*"))
  end

  def stub_query_embedding(vector)
    stub_request(:post, endpoint).to_return(
      status: 200,
      headers: { "Content-Type" => "application/json" },
      body: { data: [ { embedding: vector, index: 0 } ] }.to_json
    )
  end

  describe Tools::SearchAdrsTool do
    describe "natural language search" do
      it "returns summaries with relevance scores, best match first" do
        near = create(:adr_management_adr, title: "認証方式の選定")
        far = create(:adr_management_adr, title: "無関係の決定")
        index_adr(near, [ 1.0, 0.0 ])
        index_adr(far, [ 0.0, 1.0 ])
        stub_query_embedding([ 1.0, 0.1 ])

        text = response_text(described_class.call(query: "認証まわりの決定は？", server_context: server_context))

        expect(text).to include("natural language search")
        expect(text).to include("認証方式の選定", "関連度")
        expect(text.index("認証方式の選定")).to be < text.index("無関係の決定")
        expect(text).to include("get_adr_tool")
      end

      it "restricts to the engagement when engagement_code is given" do
        target = create(:adr_management_adr, title: "対象案件の決定")
        other = create(:adr_management_adr, title: "他案件の決定")
        index_adr(target, [ 1.0, 0.0 ])
        index_adr(other, [ 1.0, 0.0 ])
        stub_query_embedding([ 1.0, 0.0 ])

        text = response_text(described_class.call(
          query: "検索", engagement_code: target.engagement.code, server_context: server_context
        ))

        expect(text).to include("対象案件の決定")
        expect(text).not_to include("他案件の決定")
      end

      it "applies attribute filters after scoring" do
        accepted = create(:adr_management_adr, title: "承認済みの決定", status: "accepted")
        proposed = create(:adr_management_adr, title: "提案中の決定", status: "proposed")
        index_adr(accepted, [ 1.0, 0.0 ])
        index_adr(proposed, [ 1.0, 0.0 ])
        stub_query_embedding([ 1.0, 0.0 ])

        text = response_text(described_class.call(
          query: "検索", status: "accepted", server_context: server_context
        ))

        expect(text).to include("承認済みの決定")
        expect(text).not_to include("提案中の決定")
      end

      it "returns guidance instead of an error when nothing matches" do
        stub_query_embedding([ 1.0, 0.0 ])

        text = response_text(described_class.call(
          query: "検索", engagement_code: create(:adr_management_engagement).code, server_context: server_context
        ))

        expect(text).to include("0件")
        expect(text).to include("言い回し")
        expect(text).to include("案件横断")
      end

      it "suggests keyword search when the embedding API is unavailable" do
        stub_request(:post, endpoint).to_return(status: 500)

        text = response_text(described_class.call(query: "検索", server_context: server_context))

        expect(text).to include("種別: search_unavailable", "キーワード")
      end
    end

    describe "keyword and attribute search" do
      it "matches keywords against title and body, newest first, without relevance" do
        create(:adr_management_adr, title: "認証方式の選定", decided_on: Date.new(2026, 1, 1))
        create(:adr_management_adr, title: "他の決定", decision: "認証を使う方針", decided_on: Date.new(2026, 6, 1))
        create(:adr_management_adr, title: "無関係")

        text = response_text(described_class.call(keyword: "認証", server_context: server_context))

        expect(text).to include("Found 2 ADR(s)")
        expect(text).not_to include("関連度")
        expect(text.index("他の決定")).to be < text.index("認証方式の選定")
      end

      it "filters by attributes without a keyword" do
        create(:adr_management_adr, confidence: "low", title: "低信頼度の決定")
        create(:adr_management_adr, confidence: "high", title: "高信頼度の決定")

        text = response_text(described_class.call(confidence: "low", server_context: server_context))

        expect(text).to include("低信頼度の決定")
        expect(text).not_to include("高信頼度の決定")
      end

      it "filters by date range and project" do
        engagement = create(:adr_management_engagement)
        project = create(:adr_management_project, engagement: engagement, name: "2026年度")
        create(:adr_management_adr, engagement: engagement, project: project,
          title: "期間内", decided_on: Date.new(2026, 5, 1))
        create(:adr_management_adr, engagement: engagement,
          title: "期間外", decided_on: Date.new(2025, 1, 1))

        text = response_text(described_class.call(
          engagement_code: engagement.code, decided_after: "2026-01-01",
          project_name: "2026年度", server_context: server_context
        ))

        expect(text).to include("期間内")
        expect(text).not_to include("期間外")
      end

      it "notes truncation when results exceed the limit" do
        3.times { create(:adr_management_adr, title: "決定") }

        text = response_text(described_class.call(keyword: "決定", limit: 2, server_context: server_context))

        expect(text).to include("Found 3 ADR(s)", "他 1 件")
      end

      it "returns guidance when nothing matches" do
        text = response_text(described_class.call(keyword: "存在しない", server_context: server_context))
        expect(text).to include("0件")
      end
    end

    describe "reevaluation check filters" do
      it "unchecked_for_days returns due ADRs including never-checked, treating exactly N days ago as due" do
        never_checked = create(:adr_management_adr, title: "未点検の決定",
          reevaluation_conditions: "条件A")
        due = create(:adr_management_adr, title: "期限切れの決定",
          reevaluation_conditions: "条件B")
        create(:adr_management_reevaluation_check, adr: due, checked_on: Date.current - 30)
        fresh = create(:adr_management_adr, title: "点検済みの決定",
          reevaluation_conditions: "条件C")
        create(:adr_management_reevaluation_check, adr: fresh, checked_on: Date.current - 29)
        create(:adr_management_adr, title: "条件なしの決定", reevaluation_conditions: nil)

        text = response_text(described_class.call(unchecked_for_days: 30, server_context: server_context))

        expect(text).to include(never_checked.title, due.title)
        expect(text).not_to include(fresh.title, "条件なしの決定")
      end

      it "rejects unchecked_for_days below 1" do
        text = response_text(described_class.call(unchecked_for_days: 0, server_context: server_context))
        expect(text).to include("種別: invalid_input", "unchecked_for_days")
      end

      it "check_result matches on the latest check only" do
        resolved = create(:adr_management_adr, title: "解消済みの疑い",
          reevaluation_conditions: "条件")
        create(:adr_management_reevaluation_check, adr: resolved,
          checked_on: Date.current - 10, result: "suspected", note: "観測")
        create(:adr_management_reevaluation_check, adr: resolved,
          checked_on: Date.current - 1, result: "no_trigger")
        pending_adr = create(:adr_management_adr, title: "発火疑いの決定",
          reevaluation_conditions: "条件")
        create(:adr_management_reevaluation_check, adr: pending_adr,
          checked_on: Date.current - 1, result: "suspected", note: "観測")

        text = response_text(described_class.call(check_result: "suspected", server_context: server_context))

        expect(text).to include(pending_adr.title)
        expect(text).not_to include(resolved.title)
      end

      it "applies unchecked_for_days as a post-filter on the natural language path" do
        due = create(:adr_management_adr, title: "未点検の決定", reevaluation_conditions: "条件")
        fresh = create(:adr_management_adr, title: "点検済みの決定", reevaluation_conditions: "条件")
        create(:adr_management_reevaluation_check, adr: fresh, checked_on: Date.current)
        index_adr(due, [ 1.0, 0.0, 0.0 ])
        index_adr(fresh, [ 0.9, 0.1, 0.0 ])
        stub_query_embedding([ 1.0, 0.0, 0.0 ])

        text = response_text(described_class.call(
          query: "点検対象は？", unchecked_for_days: 30, server_context: server_context
        ))

        expect(text).to include(due.title)
        expect(text).not_to include(fresh.title)
      end
    end

    it "returns master_not_found for an unknown engagement" do
      text = response_text(described_class.call(
        keyword: "x", engagement_code: "nope", server_context: server_context
      ))
      expect(text).to include("種別: master_not_found")
    end
  end

  describe Tools::GetAdrTool do
    it "returns the full text with all sections" do
      engagement = create(:adr_management_engagement, code: "fabble")
      adr = create(:adr_management_adr,
        engagement: engagement, title: "認証方式の選定",
        context: "コンテキスト本文", decision: "決定本文", consequences: "結果本文",
        alternatives: "代替案本文", reevaluation_conditions: "再評価条件本文",
        reference_links: "https://example.com")
      adr.record_revision!(change_type: "created", origin: "oauth:Agent")

      text = response_text(described_class.call(
        engagement_code: "fabble", number: adr.number, server_context: server_context
      ))

      expect(text).to include("FABBLE-#{adr.number}: 認証方式の選定")
      expect(text).to include("コンテキスト本文", "決定本文", "結果本文", "代替案本文", "再評価条件本文")
      expect(text).to include("版履歴", "created", "oauth:Agent")
      expect(text).not_to include("再評価点検")
    end

    it "shows reevaluation checks newest first, capped at 5" do
      engagement = create(:adr_management_engagement, code: "fabble")
      adr = create(:adr_management_adr, engagement: engagement,
        reevaluation_conditions: "条件")
      6.times do |i|
        create(:adr_management_reevaluation_check, adr: adr,
          checked_on: Date.new(2026, 7, 1) + i, result: "no_trigger")
      end
      create(:adr_management_reevaluation_check, adr: adr,
        checked_on: Date.new(2026, 7, 10), result: "suspected", note: "無償枠改定を観測")

      text = response_text(described_class.call(
        engagement_code: "fabble", number: adr.number, server_context: server_context
      ))

      expect(text).to include("再評価点検（新しい順、最大5件）")
      expect(text).to include("2026-07-10 suspected", "無償枠改定を観測")
      expect(text.index("2026-07-10")).to be < text.index("2026-07-06")
      expect(text.scan(/no_trigger/).size).to eq(4)
      expect(text).not_to include("2026-07-01 no_trigger")
    end

    it "shows the supersession chain in both directions" do
      engagement = create(:adr_management_engagement, code: "fabble")
      old_adr = create(:adr_management_adr, engagement: engagement, status: "accepted", title: "旧決定")
      result = AdrManagement::RegisterAdr.perform(
        engagement: engagement,
        attributes: {
          title: "新決定", confidence: "high", decided_on: Date.current,
          context: "c", decision: "d", consequences: "q"
        },
        origin: "test",
        superseded_numbers: [ old_adr.number ]
      )
      new_adr = result.data

      new_text = response_text(described_class.call(
        engagement_code: "fabble", number: new_adr.number, server_context: server_context
      ))
      expect(new_text).to include("この ADR が置き換えた決定", "旧決定")

      old_text = response_text(described_class.call(
        engagement_code: "fabble", number: old_adr.number, server_context: server_context
      ))
      expect(old_text).to include("この ADR を置き換えた決定", "新決定")
    end

    it "finds the engagement case-insensitively (uppercase display form)" do
      engagement = create(:adr_management_engagement, code: "fabble")
      adr = create(:adr_management_adr, engagement: engagement, title: "認証方式の選定")

      text = response_text(described_class.call(
        engagement_code: "FABBLE", number: adr.number, server_context: server_context
      ))
      expect(text).to include("FABBLE-#{adr.number}: 認証方式の選定")
    end

    it "returns master_not_found for an unknown number" do
      engagement = create(:adr_management_engagement, code: "fabble")

      text = response_text(described_class.call(
        engagement_code: "fabble", number: 999, server_context: server_context
      ))
      expect(text).to include("種別: master_not_found", "search_adrs_tool")
    end
  end
end
