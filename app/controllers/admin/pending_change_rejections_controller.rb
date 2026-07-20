# frozen_string_literal: true

module Admin
  # 保留変更の否認。掲載内容は変更せず、否認の事実だけを会話に残す。
  # 修正指示は管理者の次の発言で行われるため、ここでは応答生成しない。
  class PendingChangeRejectionsController < BaseController
    def create
      pending_change = ContentAgent::PendingChange.find(params[:pending_change_id])
      chat = pending_change.chat

      pending_change.reject!
      chat.messages.create!(role: "user",
                            content: "（適用結果）保留変更 ##{pending_change.id} は否認されました。")

      redirect_to admin_agent_chat_path(chat)
    end
  end
end
