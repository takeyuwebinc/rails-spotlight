require "rails_helper"

RSpec.describe ContentAgent::PendingChange, type: :model do
  describe "バリデーション" do
    it "対象種別は掲載4種のみ許可する" do
      change = build(:content_agent_pending_change, target_type: "AdrManagement::Adr")

      expect(change).not_to be_valid
      expect(change.errors[:target_type]).to be_present
    end

    it "更新は対象レコードIDを必須とする" do
      change = build(:content_agent_pending_change, operation: "update", target_id: nil)

      expect(change).not_to be_valid
      expect(change.errors[:target_id]).to be_present
    end

    it "公開・非公開切替は対象レコードIDを必須とする" do
      change = build(:content_agent_pending_change, operation: "toggle_publication", target_id: nil)

      expect(change).not_to be_valid
    end

    it "空の変更内容を許可しない" do
      change = build(:content_agent_pending_change, payload: {})

      expect(change).not_to be_valid
      expect(change.errors[:payload]).to be_present
    end

    describe "新規作成の必須属性チェック" do
      it "Project は必須属性（公開日時含む）が揃っていれば有効" do
        change = build(:content_agent_pending_change,
                       target_type: "Project", operation: "create",
                       payload: {
                         "title" => "t", "description" => "d", "icon" => "i",
                         "color" => "c", "technologies" => "Ruby", "published_at" => "2026-07-20T00:00:00Z"
                       })

        expect(change).to be_valid
      end

      it "Project は公開日時が欠けていると無効" do
        change = build(:content_agent_pending_change,
                       target_type: "Project", operation: "create",
                       payload: { "title" => "t", "description" => "d", "icon" => "i",
                                  "color" => "c", "technologies" => "Ruby" })

        expect(change).not_to be_valid
        expect(change.errors[:payload].join).to include("published_at")
      end

      it "SpeakingEngagement は公開フラグが欠けていると無効" do
        change = build(:content_agent_pending_change,
                       target_type: "SpeakingEngagement", operation: "create",
                       payload: { "title" => "t", "slug" => "s", "event_name" => "e",
                                  "event_date" => "2026-07-01" })

        expect(change).not_to be_valid
      end

      it "SpeakingEngagement は公開フラグ false でもキーがあれば有効" do
        change = build(:content_agent_pending_change,
                       target_type: "SpeakingEngagement", operation: "create",
                       payload: { "title" => "t", "slug" => "s", "event_name" => "e",
                                  "event_date" => "2026-07-01", "published" => false })

        expect(change).to be_valid
      end

      it "Slide は公開日時を含む frontmatter 付き markdown が必要" do
        change = build(:content_agent_pending_change,
                       target_type: "Slide", operation: "create",
                       payload: { "content" => "---\ntitle: t\n---\n本文" })

        expect(change).not_to be_valid
      end

      it "Slide は frontmatter に category: slide が必要" do
        change = build(:content_agent_pending_change,
                       target_type: "Slide", operation: "create",
                       payload: { "content" => "---\ntitle: t\npublished_date: 2026-07-15\n---\n本文" })

        expect(change).not_to be_valid
        expect(change.errors[:payload].join).to include("category")
      end

      it "Slide は published_date と category: slide が揃えば有効" do
        change = build(:content_agent_pending_change,
                       target_type: "Slide", operation: "create",
                       payload: { "content" => "---\ntitle: t\npublished_date: 2026-07-15\ncategory: slide\n---\n本文" })

        expect(change).to be_valid
      end
    end
  end

  describe "状態遷移" do
    it "承認待ちを否認済みにできる" do
      change = create(:content_agent_pending_change)

      change.reject!

      expect(change.reload).to be_rejected
    end

    it "承認待ち以外の否認はエラーになる" do
      change = create(:content_agent_pending_change, status: "approved")

      expect { change.reject! }.to raise_error(ContentAgent::PendingChange::InvalidTransition)
    end

    it "承認待ちと適用失敗は置換済みにできる" do
      pending_change = create(:content_agent_pending_change)
      failed_change = create(:content_agent_pending_change, status: "failed")

      pending_change.supersede!
      failed_change.supersede!

      expect(pending_change.reload).to be_superseded
      expect(failed_change.reload).to be_superseded
    end

    it "承認済みの置換はエラーになる" do
      change = create(:content_agent_pending_change, status: "approved")

      expect { change.supersede! }.to raise_error(ContentAgent::PendingChange::InvalidTransition)
    end
  end
end
