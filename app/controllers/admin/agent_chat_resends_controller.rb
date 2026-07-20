# frozen_string_literal: true

module Admin
  # 応答生成の再実行（エラー時の再送）。発言は既に保存されているため、
  # 新しいメッセージを作らずジョブだけを再投入する。
  class AgentChatResendsController < BaseController
    def create
      chat = Chat.find(params[:agent_chat_id])
      ContentAgent::GenerateResponseJob.perform_later(chat.id)
      redirect_to admin_agent_chat_path(chat)
    end
  end
end
