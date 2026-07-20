# frozen_string_literal: true

module Admin
  class AgentChatMessagesController < BaseController
    def create
      chat = Chat.find(params[:agent_chat_id])
      content = params.require(:message).require(:content)

      if content.strip.present?
        chat.messages.create!(role: "user", content: content.strip)
        ContentAgent::GenerateResponseJob.perform_later(chat.id)
      end

      redirect_to admin_agent_chat_path(chat)
    end
  end
end
