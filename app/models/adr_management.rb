# frozen_string_literal: true

module AdrManagement
  # タスク種別ごとの使用モデル（さくらのAI Engine のモデル識別子）。
  # 割当はここを書き換えるだけで変更できる
  MODEL_ASSIGNMENTS = {
    quality_assessment: "gpt-oss-120b"
  }.freeze

  def self.table_name_prefix
    "adr_management_"
  end

  def self.model_for(task)
    MODEL_ASSIGNMENTS.fetch(task)
  end
end
