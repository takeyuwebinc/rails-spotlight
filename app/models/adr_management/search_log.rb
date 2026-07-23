# frozen_string_literal: true

module AdrManagement
  # ADR 検索の実行記録。取り逃がし（返るべき ADR が返らない）の分析と
  # 0件率の把握のため、クエリ・フィルタ・返却結果を検索のたびに残す。
  # クエリ本文には取引先の機密情報が含まれうるが、保存先はローカル DB で
  # 外部送信はなく、ADR 本文と同じ機密性水準で扱う。
  class SearchLog < ApplicationRecord
    MODES = %w[natural_language keyword].freeze

    belongs_to :engagement, class_name: "AdrManagement::Engagement", optional: true

    validates :mode, presence: true, inclusion: { in: MODES }
    validates :result_count, presence: true,
      numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :origin, presence: true

    # 期間内の検索実行数（モード別）と0件検索の数を集計して返す
    def self.summary(since:)
      logs = where(created_at: since..)
      {
        total: logs.count,
        by_mode: logs.group(:mode).count,
        zero_result_count: logs.where(result_count: 0).count
      }
    end
  end
end
