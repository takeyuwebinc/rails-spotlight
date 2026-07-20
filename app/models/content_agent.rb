# frozen_string_literal: true

module ContentAgent
  # タスク種別ごとの使用モデル（さくらのAI Engine のモデル識別子）。
  # 会話進行はツール実行（tool calling）必須のため、非対応の
  # llm-jp-3.1-8x13b-instruct4 を割り当ててはならない。
  # 割当はここを書き換えるだけで変更できる（管理者が画面で選ぶ機能ではない）。
  MODEL_ASSIGNMENTS = {
    conversation: "gpt-oss-120b",
    extraction: "Qwen3-Coder-30B-A3B-Instruct",
    summarization: "Qwen3-Coder-30B-A3B-Instruct"
  }.freeze

  def self.table_name_prefix
    "content_agent_"
  end

  def self.model_for(task)
    MODEL_ASSIGNMENTS.fetch(task)
  end
end
