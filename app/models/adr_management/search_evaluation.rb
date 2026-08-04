# frozen_string_literal: true

module AdrManagement
  # ゴールデンクエリ評価の実行履歴。recall の推移を追い、検索実装の変更や
  # コーパスの変化による劣化を検知する。ゴールデンクエリ集は実行時に
  # 変化しうるため、実行時点の内訳（details）も保存する。
  class SearchEvaluation < ApplicationRecord
    validates :k, presence: true, numericality: { only_integer: true, greater_than: 0 }
    validates :recall, presence: true,
      numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }
    validates :origin, presence: true

    scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  end
end
