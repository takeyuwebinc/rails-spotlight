# frozen_string_literal: true

require "rails_helper"

# 掲載内容管理支援エージェントのシナリオ評価。実 LLM API を使用する。
# 実行方法・判定方針は spec/support/agent_eval.rb を参照。
RSpec.describe "掲載内容管理支援エージェント評価", :agent_eval do
  describe "新規登録" do
    it "UsesItem: URL 未指定でも公式サイトを検索して url を含めて提案する" do
      eval_attempts do |attempt|
        chat = ContentAgent::ConversationAgent.create!
        run_agent_turn(chat, <<~MSG)
          UsesItem を新規登録してください。
          name: Visual Studio Code, slug: eval-vscode-#{attempt}, category: software,
          description: メインで使っているエディタ, 公開状態: 非公開（published: false）
          確認は不要です。このまま提案してください。
        MSG

        change = chat.pending_changes.pending.sole
        expect(change).to have_attributes(target_type: "UsesItem", operation: "create")
        expect(change.payload["url"]).to match(%r{\Ahttps?://})
        expect(change.payload["published"]).to be(false)
        expect(UsesItem.where(slug: "eval-vscode-#{attempt}")).to be_empty
      end
    end

    it "SpeakingEngagement: タグ含む必須属性を揃えて提案する" do
      eval_attempts do |attempt|
        chat = ContentAgent::ConversationAgent.create!
        run_agent_turn(chat, <<~MSG)
          登壇実績を登録してください。
          タイトル: Rails と LLM エージェント, slug: eval-talk-#{attempt},
          イベント名: Fukuoka.rb, 開催日: 2026-07-10, 公開: true, タグ: Ruby, Rails
          確認は不要です。このまま提案してください。
        MSG

        change = chat.pending_changes.pending.sole
        expect(change).to have_attributes(target_type: "SpeakingEngagement", operation: "create")
        expect(change.payload).to include("title", "slug", "event_name", "event_date", "published")
        expect(Array(change.payload["tags"])).to include("Ruby", "Rails")
        expect(SpeakingEngagement.where(slug: "eval-talk-#{attempt}")).to be_empty
      end
    end

    it "Project: 公開日時を含めて提案する" do
      eval_attempts do
        chat = ContentAgent::ConversationAgent.create!
        run_agent_turn(chat, <<~MSG)
          Project を新規登録してください。
          title: 評価用プロジェクト, description: エージェント評価のためのプロジェクトです,
          icon: fa-solid fa-robot, color: blue, technologies: Ruby, Rails,
          公開日時: 2026-07-01 09:00
          確認は不要です。このまま提案してください。
        MSG

        change = chat.pending_changes.pending.sole
        expect(change).to have_attributes(target_type: "Project", operation: "create")
        expect(change.payload["published_at"]).to be_present
        expect(Project.count).to eq(0)
      end
    end

    it "Slide: frontmatter（published_date, category: slide）付き markdown で提案する" do
      eval_attempts do |attempt|
        chat = ContentAgent::ConversationAgent.create!
        run_agent_turn(chat, <<~MSG)
          スライドを登録してください。
          タイトル: LLM エージェント入門, slug: eval-slide-#{attempt},
          説明: 社内勉強会の資料, 公開日: 2026-07-15
          ページは2枚: 1枚目「タイトルページ」、2枚目「まとめ」
          確認は不要です。このまま提案してください。
        MSG

        change = chat.pending_changes.pending.sole
        expect(change).to have_attributes(target_type: "Slide", operation: "create")
        expect(change.payload["content"]).to match(/^published_date:/)
        expect(change.payload["content"]).to include("category: slide")
        expect(Slide.where(slug: "eval-slide-#{attempt}")).to be_empty
      end
    end
  end

  describe "更新・公開切替" do
    it "UsesItem: 既存レコードの説明変更を update 提案にする" do
      eval_attempts do |attempt|
        item = UsesItem.create!(name: "HHKB", slug: "eval-hhkb-#{attempt}", category: "hardware",
                                description: "静電容量無接点キーボード", published: true)
        chat = ContentAgent::ConversationAgent.create!
        run_agent_turn(chat, <<~MSG)
          UsesItem「HHKB」（slug: eval-hhkb-#{attempt}）の説明を
          「メインで使っている静電容量無接点キーボード」に更新してください。
          確認は不要です。このまま提案してください。
        MSG

        change = chat.pending_changes.pending.sole
        expect(change).to have_attributes(target_type: "UsesItem", operation: "update",
                                          target_id: item.id)
        expect(change.payload["description"]).to include("メイン")
        expect(item.reload.description).to eq("静電容量無接点キーボード")
      end
    end

    it "SpeakingEngagement: 非公開化を toggle_publication 提案にする" do
      eval_attempts do |attempt|
        engagement = SpeakingEngagement.create!(
          title: "評価用登壇", slug: "eval-toggle-#{attempt}", event_name: "Event",
          event_date: "2026-07-01", published: true
        )
        chat = ContentAgent::ConversationAgent.create!
        run_agent_turn(chat, <<~MSG)
          登壇実績「評価用登壇」（slug: eval-toggle-#{attempt}）を非公開にしてください。
          確認は不要です。このまま提案してください。
        MSG

        change = chat.pending_changes.pending.sole
        expect(change).to have_attributes(target_type: "SpeakingEngagement",
                                          operation: "toggle_publication",
                                          target_id: engagement.id)
        expect(change.payload["published"]).to be(false)
        expect(engagement.reload.published).to be(true)
      end
    end
  end

  describe "承認フロー" do
    it "修正指示で旧提案を置換して新提案を出す" do
      eval_attempts do |attempt|
        chat = ContentAgent::ConversationAgent.create!
        run_agent_turn(chat, <<~MSG)
          UsesItem を新規登録してください。
          name: Alacritty, slug: eval-alacritty-#{attempt}, category: software,
          description: ターミナルエミュレータ, published: false, url は不要です。
          確認は不要です。このまま提案してください。
        MSG
        first_change = chat.pending_changes.pending.sole

        run_agent_turn(chat, "slug を eval-alacritty-revised-#{attempt} に変えて提案し直してください。")

        expect(first_change.reload).to be_superseded
        revised = chat.pending_changes.pending.sole
        expect(revised.payload["slug"]).to eq("eval-alacritty-revised-#{attempt}")
      end
    end

    it "承認・適用の結果通知に完了報告で応答する" do
      eval_attempts do |attempt|
        chat = ContentAgent::ConversationAgent.create!
        run_agent_turn(chat, <<~MSG)
          UsesItem を新規登録してください。
          name: Ghostty, slug: eval-ghostty-#{attempt}, category: software,
          description: ターミナルエミュレータ, published: false, url は不要です。
          確認は不要です。このまま提案してください。
        MSG
        change = chat.pending_changes.pending.sole

        result = ContentAgent::ApplyPendingChange.perform(pending_change: change)
        expect(result.success?).to be(true)
        expect(UsesItem.where(slug: "eval-ghostty-#{attempt}")).to be_present

        run_agent_turn(chat, "（適用結果）保留変更 ##{change.id} は承認され、適用に成功しました。")
        expect(chat.messages.where(role: "assistant").last.content).to be_present
      end
    end
  end

  describe "読み取り" do
    it "一覧の依頼では保留変更を作らない" do
      eval_attempts do |attempt|
        UsesItem.create!(name: "評価用アイテム#{attempt}", slug: "eval-listing-#{attempt}",
                         category: "hardware", description: "d", published: true)
        chat = ContentAgent::ConversationAgent.create!
        run_agent_turn(chat, "登録済みの UsesItem を一覧で見せてください。")

        expect(chat.pending_changes).to be_empty
        assistant = chat.messages.where(role: "assistant").last
        expect(assistant.content).to include("評価用アイテム#{attempt}")
      end
    end
  end
end
