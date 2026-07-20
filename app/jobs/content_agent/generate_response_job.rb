# frozen_string_literal: true

module ContentAgent
  # 会話進行エージェントを実行して応答を生成する。生成中のテキスト断片は
  # Turbo Streams で逐次配信し、完了・失敗時はページ再描画を配信する。
  # LLM 呼び出しは長時間かかるため Web リクエストでは実行しない。
  class GenerateResponseJob < ApplicationJob
    queue_as :default

    # 同一会話の応答生成は同時に 1 件のみ（多重送信・二重実行の防止）
    limits_concurrency to: 1, key: ->(chat_id) { "content_agent_chat_#{chat_id}" }

    def perform(chat_id)
      chat = Chat.find(chat_id)
      chat.assign_title_from(first_user_message_content(chat))
      chat.update!(last_error: nil) if chat.last_error.present?

      agent = ConversationAgent.new(chat: chat, persist_instructions: false)
      agent.complete do |chunk|
        broadcast_chunk(chat, chunk.content) if chunk.content.present?
      end

      # 保留変更のプレビューカードは、この完了時の再描画でのみ画面に現れる。
      # 承認・否認の操作を応答の生成完了後にだけ有効化する保証がこの構造に
      # 依存しているため、生成途中でカードを配信してはならない。
      broadcast_refresh(chat)
    rescue StandardError => e
      Rails.error.report(e, context: { chat_id: chat_id }, severity: :error)
      chat.update!(last_error: error_notice(e))
      broadcast_refresh(chat)
    end

    private

    def first_user_message_content(chat)
      chat.messages.where(role: "user").order(:id).pick(:content)
    end

    def broadcast_chunk(chat, content)
      Turbo::StreamsChannel.broadcast_append_to(
        stream_name(chat),
        target: "agent_streaming_content",
        html: ERB::Util.html_escape(content)
      )
    end

    def broadcast_refresh(chat)
      Turbo::StreamsChannel.broadcast_refresh_to(stream_name(chat))
    end

    def stream_name(chat)
      "content_agent_chat_#{chat.id}"
    end

    def error_notice(error)
      if error.message.match?(/context|maximum.*tokens?|tokens?.*(limit|exceed)/i)
        "コンテキスト長の上限を超えました。再送では解決できないため、新しい会話で続行してください。"
      else
        "応答の生成に失敗しました。再送で続行できます。（#{error.message.to_s.truncate(200)}）"
      end
    end
  end
end
