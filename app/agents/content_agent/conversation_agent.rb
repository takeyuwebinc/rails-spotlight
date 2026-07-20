# frozen_string_literal: true

module ContentAgent
  # 会話進行エージェント。管理者へのヒアリング・ツール実行の判断・
  # 提案文の生成を担う。書き込みは ProposeChangeTool（保留変更の作成）
  # までしか行えず、掲載内容への反映は管理者の承認を経た適用処理が行う。
  # 指示文は app/prompts/content_agent/conversation_agent/instructions.txt.erb
  # から規約により自動読み込みされる。
  class ConversationAgent < RubyLLM::Agent
    chat_model Chat

    model ContentAgent.model_for(:conversation), provider: :openai, assume_model_exists: true

    tools do
      [
        ListContentsTool.new,
        GetContentTool.new,
        FetchUrlTool.new,
        WebSearchTool.new,
        ExtractAttributesTool.new(chat: chat),
        ProposeChangeTool.new(chat: chat)
      ]
    end
  end
end
