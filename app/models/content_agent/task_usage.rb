# frozen_string_literal: true

module ContentAgent
  # 会話進行の外で実行される下位タスク（属性抽出・検索結果要約）の
  # LLM 利用量。メッセージに残らない呼び出し分を会話コスト概算に
  # 含めるために記録する。
  class TaskUsage < ApplicationRecord
    TASK_KINDS = %w[extraction summarization].freeze

    belongs_to :chat

    validates :task_kind, inclusion: { in: TASK_KINDS }
    validates :model_id, presence: true
    validates :input_tokens, :output_tokens,
              numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  end
end
