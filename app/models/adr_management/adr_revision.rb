# frozen_string_literal: true

module AdrManagement
  # ADR の版履歴（スナップショット方式）。作成・更新・置換の一体操作による
  # ステータス変更・所属案件変更の各操作のトランザクション内で明示的に記録する。
  # 誤更新時に変更前の内容を確認・復元するための業務追跡が目的。
  # snapshot は変更前の全項目（作成時は変更前が存在しないため nil）。
  class AdrRevision < ApplicationRecord
    CHANGE_TYPES = %w[created updated status_changed engagement_changed].freeze

    belongs_to :adr, class_name: "AdrManagement::Adr"

    validates :change_type, presence: true, inclusion: { in: CHANGE_TYPES }
    validates :origin, presence: true

    scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  end
end
