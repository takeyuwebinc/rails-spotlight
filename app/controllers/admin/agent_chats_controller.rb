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
    end

    def create
      chat = Chat.create!
      redirect_to admin_agent_chat_path(chat)
    end
  end
end
