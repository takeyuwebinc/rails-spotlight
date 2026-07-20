# frozen_string_literal: true

module Admin
  class AgentChatsController < BaseController
    def index
      @chats = Chat.recent
    end

    def show
      @chat = Chat.find(params[:id])
      @messages = @chat.messages.order(:id).includes(:tool_calls)
      @pending_changes_by_message = @chat.pending_changes.ordered.group_by(&:message_id)
      @cost = ContentAgent::ChatCost.for(@chat)
    end

    def create
      # 素の Chat.create! ではエージェントのモデル設定が会話に載らないため、
      # Rails モードの Agent 経由で作成する
      chat = ContentAgent::ConversationAgent.create!
      redirect_to admin_agent_chat_path(chat)
    end
  end
end
