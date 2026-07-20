require "rails_helper"

RSpec.describe ContentAgent::ProposeChangeTool do
  describe "#execute" do
    let(:chat) { create(:chat) }

    it "保留変更を作成し掲載内容は変更しない" do
      result = described_class.new(chat: chat).execute(
        target_type: "UsesItem",
        operation: "create",
        payload_json: {
          name: "HHKB", slug: "hhkb", category: "hardware",
          description: "キーボード", published: true,
          url: "https://happyhackingkb.com/jp/"
        }.to_json
      )

      expect(result[:pending_change_id]).to be_present
      change = chat.pending_changes.find(result[:pending_change_id])
      expect(change).to be_pending
      expect(change.payload["name"]).to eq("HHKB")
      expect(UsesItem.count).to eq(0)
    end

    it "UsesItem の新規作成で url キーがないと Web 検索を促すエラーを返す" do
      result = described_class.new(chat: chat).execute(
        target_type: "UsesItem",
        operation: "create",
        payload_json: {
          name: "HHKB", slug: "hhkb", category: "hardware",
          description: "キーボード", published: true
        }.to_json
      )

      expect(result[:error]).to include("web_search")
      expect(chat.pending_changes.count).to eq(0)
    end

    it "公式サイトが存在しない場合は url: null を明示すれば提案できる" do
      result = described_class.new(chat: chat).execute(
        target_type: "UsesItem",
        operation: "create",
        payload_json: {
          name: "自作キーボード", slug: "diy-keyboard", category: "hardware",
          description: "d", published: false, url: nil
        }.to_json
      )

      expect(result[:pending_change_id]).to be_present
    end

    it "必須属性が不足していると保留変更を作らずエラーを返す" do
      result = described_class.new(chat: chat).execute(
        target_type: "UsesItem",
        operation: "create",
        payload_json: { name: "HHKB", url: nil }.to_json
      )

      expect(result[:error]).to include("必須属性")
      expect(chat.pending_changes.count).to eq(0)
    end

    it "JSON が不正な場合はエラーを返す" do
      result = described_class.new(chat: chat).execute(
        target_type: "UsesItem", operation: "create", payload_json: "{oops"
      )

      expect(result[:error]).to include("JSON")
    end

    it "再提案時に置き換え対象を置換済みへ遷移させる" do
      old_change = create(:content_agent_pending_change, chat: chat)

      result = described_class.new(chat: chat).execute(
        target_type: "UsesItem",
        operation: "create",
        payload_json: {
          name: "HHKB", slug: "hhkb-2", category: "hardware",
          description: "d", published: false,
          url: "https://happyhackingkb.com/jp/"
        }.to_json,
        replaces_pending_change_id: old_change.id
      )

      expect(result[:pending_change_id]).to be_present
      expect(old_change.reload).to be_superseded
    end

    it "不正な操作種別はエラーを返す" do
      result = described_class.new(chat: chat).execute(
        target_type: "UsesItem", operation: "delete", payload_json: "{}"
      )

      expect(result[:error]).to be_present
      expect(chat.pending_changes.count).to eq(0)
    end
  end
end
