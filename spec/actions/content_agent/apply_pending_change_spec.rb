require "rails_helper"

RSpec.describe ContentAgent::ApplyPendingChange do
  describe "#perform" do
    context "新規作成（UsesItem）" do
      it "レコードを作成し保留変更を承認済みにする" do
        change = create(:content_agent_pending_change)

        result = described_class.perform(pending_change: change)

        expect(result.success?).to be(true)
        item = UsesItem.find_by(slug: "macbook-pro")
        expect(item).to have_attributes(name: "MacBook Pro", category: "hardware", published: true)
        expect(change.reload).to be_approved
        expect(change.applied_at).to be_present
      end

      it "許可外の属性は無視する" do
        change = create(:content_agent_pending_change,
                        payload: {
                          "name" => "n", "slug" => "guarded", "category" => "hardware",
                          "description" => "d", "published" => true,
                          "id" => 9999, "created_at" => "2000-01-01"
                        })

        described_class.perform(pending_change: change)

        item = UsesItem.find_by(slug: "guarded")
        expect(item.id).not_to eq(9999)
      end
    end

    context "更新（SpeakingEngagement・タグ付け替え）" do
      it "属性とタグを更新する" do
        engagement = SpeakingEngagement.create!(
          title: "旧タイトル", slug: "talk-1", event_name: "Event", event_date: "2026-07-01"
        )
        engagement.tags << Tag.create!(name: "OldTag")
        change = create(:content_agent_pending_change,
                        target_type: "SpeakingEngagement", operation: "update",
                        target_id: engagement.id,
                        payload: { "title" => "新タイトル", "tags" => [ "Ruby", "Rails" ] })

        result = described_class.perform(pending_change: change)

        expect(result.success?).to be(true)
        engagement.reload
        expect(engagement.title).to eq("新タイトル")
        expect(engagement.tags.pluck(:name)).to contain_exactly("Ruby", "Rails")
      end
    end

    context "公開・非公開切替" do
      it "UsesItem の published を変更する" do
        item = UsesItem.create!(name: "n", slug: "toggle-me", category: "hardware",
                                description: "d", published: true)
        change = create(:content_agent_pending_change,
                        target_type: "UsesItem", operation: "toggle_publication",
                        target_id: item.id, payload: { "published" => false })

        result = described_class.perform(pending_change: change)

        expect(result.success?).to be(true)
        expect(item.reload.published).to be(false)
      end
    end

    context "Slide（markdown 取り込み）" do
      it "取り込み成功で承認済みになる" do
        slide = build(:slide)
        allow(Slide).to receive(:import_from_markdown).and_return(slide)
        change = create(:content_agent_pending_change,
                        target_type: "Slide", operation: "create",
                        payload: { "content" => "---\npublished_date: 2026-07-20\ncategory: slide\n---\n# p" })

        result = described_class.perform(pending_change: change)

        expect(result.success?).to be(true)
        expect(Slide).to have_received(:import_from_markdown)
        expect(change.reload).to be_approved
      end

      it "取り込み失敗（nil 返却）で適用失敗になる" do
        allow(Slide).to receive(:import_from_markdown).and_return(nil)
        change = create(:content_agent_pending_change,
                        target_type: "Slide", operation: "create",
                        payload: { "content" => "---\npublished_date: 2026-07-20\ncategory: slide\n---\n# p" })

        result = described_class.perform(pending_change: change)

        expect(result.failure?).to be(true)
        expect(change.reload).to be_failed
        expect(change.apply_error).to be_present
      end
    end

    context "バリデーションエラー" do
      it "適用失敗として記録し掲載内容を変更しない" do
        SpeakingEngagement.create!(title: "t", slug: "dup", event_name: "e", event_date: "2026-07-01")
        change = create(:content_agent_pending_change,
                        target_type: "SpeakingEngagement", operation: "create",
                        payload: { "title" => "t2", "slug" => "dup", "event_name" => "e2",
                                   "event_date" => "2026-07-02", "published" => true })

        result = described_class.perform(pending_change: change)

        expect(result.failure?).to be(true)
        expect(change.reload).to be_failed
        expect(change.apply_error).to include("Slug")
        expect(SpeakingEngagement.where(slug: "dup").count).to eq(1)
      end
    end

    context "承認待ち以外" do
      it "適用せず失敗を返す" do
        change = create(:content_agent_pending_change, status: "rejected")

        result = described_class.perform(pending_change: change)

        expect(result.failure?).to be(true)
        expect(change.reload).to be_rejected
      end
    end
  end
end
