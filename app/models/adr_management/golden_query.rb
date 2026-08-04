# frozen_string_literal: true

module AdrManagement
  # 検索品質回帰のゴールデンクエリ。「このクエリならこの ADR が上位に出るべき」
  # という期待ペアで、評価（recall@k）の分母になる。取り逃がし報告・検索ログ
  # から人手で採用して育てる。期待 ADR は外部参照で持ち、ADR の削除に連動して
  # 消えるため、存在しない期待による評価エラーは起きない。
  class GoldenQuery < ApplicationRecord
    belongs_to :adr, class_name: "AdrManagement::Adr"

    validates :query, presence: true
    validates :origin, presence: true

    scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  end
end
