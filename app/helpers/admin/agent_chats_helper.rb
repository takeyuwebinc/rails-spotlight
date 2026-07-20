# frozen_string_literal: true

module Admin
  module AgentChatsHelper
    OPERATION_LABELS = {
      "create" => "新規作成",
      "update" => "更新",
      "toggle_publication" => "公開・非公開切替"
    }.freeze

    STATUS_LABELS = {
      "pending" => "承認待ち",
      "approved" => "適用済み",
      "rejected" => "否認",
      "superseded" => "置換済み",
      "failed" => "適用失敗"
    }.freeze

    STATUS_BADGE_CLASSES = {
      "pending" => "bg-amber-100 text-amber-800",
      "approved" => "bg-green-100 text-green-800",
      "rejected" => "bg-zinc-200 text-zinc-600",
      "superseded" => "bg-zinc-200 text-zinc-600",
      "failed" => "bg-red-100 text-red-800"
    }.freeze

    PUBLICATION_KEYS = %w[published published_at].freeze

    def pending_change_operation_label(pending_change)
      OPERATION_LABELS.fetch(pending_change.operation, pending_change.operation)
    end

    def pending_change_status_label(pending_change)
      STATUS_LABELS.fetch(pending_change.status, pending_change.status)
    end

    def pending_change_status_badge_class(pending_change)
      STATUS_BADGE_CLASSES.fetch(pending_change.status, "bg-zinc-200 text-zinc-600")
    end

    # コスト概算の表示（円・小数第2位）。単価未設定モデルの分は合計から
    # 除外されているため、その旨を注記する。
    def format_agent_cost(cost_result)
      text = "¥#{format('%.2f', cost_result.total_yen)}"
      text += "（#{cost_result.unknown_model_ids.join(', ')} は単価未設定のため除外）" if cost_result.unknown_model_ids.any?
      text
    end

    # プレビュー表の行データ。更新・公開切替では対象レコードの現在値を
    # 表示時に取得して新旧比較できるようにする（保留変更には旧値を保存しない）。
    def pending_change_rows(pending_change)
      current = pending_change.target_record&.attributes || {}
      pending_change.payload.except("content", "tags").map do |key, value|
        {
          key: key,
          current: pending_change.operation_create? ? nil : current[key],
          proposed: value,
          publication: PUBLICATION_KEYS.include?(key)
        }
      end
    end
  end
end
