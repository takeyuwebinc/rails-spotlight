# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::AgentChats", type: :request do
  include ActiveJob::TestHelper

  describe "認証" do
    it "未ログインでは一覧にアクセスできない" do
      get admin_agent_chats_path
      expect(response).to redirect_to(admin_login_path)
    end

    it "未ログインでは承認できない" do
      change = create(:content_agent_pending_change)
      post admin_pending_change_approval_path(change)
      expect(response).to redirect_to(admin_login_path)
      expect(change.reload).to be_pending
    end
  end

  describe "ログイン済み" do
    before { sign_in_admin }

    describe "GET /admin/agent_chats" do
      it "会話一覧を表示する" do
        create(:chat, title: "登壇の登録")

        get admin_agent_chats_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include("登壇の登録")
      end
    end

    describe "POST /admin/agent_chats" do
      it "会話を作成して会話画面へ遷移する" do
        expect { post admin_agent_chats_path }.to change(Chat, :count).by(1)
        expect(response).to redirect_to(admin_agent_chat_path(Chat.last))
      end
    end

    describe "GET /admin/agent_chats/:id" do
      it "メッセージと保留変更プレビューを表示する" do
        chat = create(:chat)
        chat.messages.create!(role: "user", content: "HHKB を登録して")
        chat.messages.create!(role: "assistant", content: "スラッグはどうしますか？")
        create(:content_agent_pending_change, chat: chat)

        get admin_agent_chat_path(chat)

        expect(response.body).to include("HHKB を登録して")
        expect(response.body).to include("スラッグはどうしますか？")
        expect(response.body).to include("承認して適用")
        expect(response.body).to include("承認待ち")
      end

      it "エラーがある場合は再送導線を表示する" do
        chat = create(:chat, last_error: "応答の生成に失敗しました。再送で続行できます。")

        get admin_agent_chat_path(chat)

        expect(response.body).to include("再送")
        expect(response.body).to include("応答の生成に失敗しました")
      end
    end

    describe "POST /admin/agent_chats/:id/messages" do
      it "発言を保存し応答生成ジョブを投入する" do
        chat = create(:chat)

        expect do
          post admin_agent_chat_messages_path(chat), params: { message: { content: "登壇を登録して" } }
        end.to have_enqueued_job(ContentAgent::GenerateResponseJob).with(chat.id)

        expect(chat.messages.where(role: "user").last.content).to eq("登壇を登録して")
        expect(response).to redirect_to(admin_agent_chat_path(chat))
      end

      it "空白のみの発言は保存しない" do
        chat = create(:chat)

        expect do
          post admin_agent_chat_messages_path(chat), params: { message: { content: "  " } }
        end.not_to have_enqueued_job
        expect(chat.messages.count).to eq(0)
      end
    end

    describe "POST /admin/agent_chats/:id/resend" do
      it "メッセージを増やさずジョブのみ再投入する" do
        chat = create(:chat)
        chat.messages.create!(role: "user", content: "hi")

        expect do
          post admin_agent_chat_resend_path(chat)
        end.to have_enqueued_job(ContentAgent::GenerateResponseJob).with(chat.id)
        expect(chat.messages.count).to eq(1)
      end
    end

    describe "POST /admin/pending_changes/:id/approval" do
      it "適用に成功すると掲載内容へ反映し結果を通知する" do
        change = create(:content_agent_pending_change)

        expect do
          post admin_pending_change_approval_path(change)
        end.to have_enqueued_job(ContentAgent::GenerateResponseJob)

        expect(change.reload).to be_approved
        expect(UsesItem.find_by(slug: "macbook-pro")).to be_present
        notice = change.chat.messages.where(role: "user").last
        expect(notice.content).to include("適用に成功")
      end

      it "適用に失敗すると失敗を通知し掲載内容は変更されない" do
        UsesItem.create!(name: "既存", slug: "macbook-pro", category: "hardware",
                         description: "d", published: true)
        change = create(:content_agent_pending_change)

        post admin_pending_change_approval_path(change)

        expect(change.reload).to be_failed
        expect(change.chat.messages.where(role: "user").last.content).to include("失敗")
        expect(UsesItem.find_by(slug: "macbook-pro").name).to eq("既存")
      end
    end

    describe "POST /admin/pending_changes/:id/rejection" do
      it "否認して掲載内容を変更せず応答生成もしない" do
        change = create(:content_agent_pending_change)

        expect do
          post admin_pending_change_rejection_path(change)
        end.not_to have_enqueued_job(ContentAgent::GenerateResponseJob)

        expect(change.reload).to be_rejected
        expect(UsesItem.count).to eq(0)
        expect(change.chat.messages.where(role: "user").last.content).to include("否認")
      end
    end
  end
end
