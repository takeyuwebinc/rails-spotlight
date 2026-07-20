# frozen_string_literal: true

module Admin
  # 保留変更の承認。掲載内容への反映は ApplyPendingChange（承認ゲートの
  # 適用処理）だけが行い、結果はエージェントへ通知して完了報告・修正提案の
  # 応答生成につなげる。
  class PendingChangeApprovalsController < BaseController
    def create
      pending_change = ContentAgent::PendingChange.find(params[:pending_change_id])
      chat = pending_change.chat

      result = ContentAgent::ApplyPendingChange.perform(pending_change: pending_change)
      notice = if result.success?
        "（適用結果）保留変更 ##{pending_change.id} は承認され、適用に成功しました。"
      else
        "（適用結果）保留変更 ##{pending_change.id} の適用に失敗しました: #{result.errors.join(', ')}"
      end
      chat.messages.create!(role: "user", content: notice)
      ContentAgent::GenerateResponseJob.perform_later(chat.id)

      redirect_to admin_agent_chat_path(chat)
    end
  end
end
