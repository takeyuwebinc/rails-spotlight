# frozen_string_literal: true

module AdrManagement
  # ADR 検索の取り逃がし報告。検索では見つからなかったが関連 ADR が
  # 存在した事例（別経路で到達した、または存在を知っていたが出なかった）を
  # エージェントが検知したときだけ記録する。埋め込み検索の主要な失敗モード
  # （言い換えに弱い）を直接観測できる唯一のシグナルであり、検索方式の
  # 見直し判断（再評価条件の点検）の根拠になる。
  class SearchMissReport < ApplicationRecord
    belongs_to :adr, class_name: "AdrManagement::Adr", optional: true

    validates :query, presence: true
    validates :note, presence: true
    validates :origin, presence: true

    scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  end
end
