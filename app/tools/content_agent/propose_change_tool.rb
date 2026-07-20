# frozen_string_literal: true

module ContentAgent
  # 掲載内容への変更を保留変更として提案する（書き込み系）。
  # このツールは掲載内容のテーブルを一切変更しない。作成した保留変更は
  # 画面にプレビューとして表示され、管理者の承認操作を経た適用処理だけが
  # 掲載内容へ反映する。必須属性が不足している提案は保留変更を作らず
  # エラーを返すので、不足分を管理者にヒアリングしてから再提案すること。
  class ProposeChangeTool < RubyLLM::Tool
    # 既定のツール名は名前空間込み（content_agent--propose_change）になり、
    # モデルが指示文中の短い名前で呼び出して失敗しやすいため短縮名に固定する
    def name = "propose_change"

    description "掲載内容への変更（新規作成・更新・公開/非公開切替）を提案する。" \
                "実行してもデータベースは変更されず、管理者が画面で承認して初めて反映される。" \
                "新規作成は必須属性（公開状態を含む）をすべて payload_json に含めること。" \
                "修正版を出し直す場合は replaces_pending_change_id に置き換える提案のIDを渡すこと。"

    param :target_type, desc: "対象種別: Project / SpeakingEngagement / UsesItem / Slide"
    param :operation, desc: "操作種別: create / update / toggle_publication"
    param :payload_json,
          desc: "変更内容のJSON文字列。属性名と値の組（例: {\"title\":\"...\",\"published\":true}）。" \
                "タグは tags キーに名前の配列。Slide の作成・更新は content キーに frontmatter 付き markdown 全文。"
    param :target_id, type: "integer", desc: "対象レコードID（update/toggle_publication で必須）", required: false
    param :replaces_pending_change_id, type: "integer",
          desc: "この提案で置き換える既存の保留変更ID（修正版の再提案時）", required: false

    def initialize(chat:)
      super()
      @chat = chat
    end

    def execute(target_type:, operation:, payload_json:, target_id: nil, replaces_pending_change_id: nil)
      payload = JSON.parse(payload_json)
      return { error: "payload_json はオブジェクト（{...}）にしてください" } unless payload.is_a?(Hash)

      # UsesItem の公式サイト URL は Web 検索で自動収集する運用のため、
      # url キーなしの新規作成提案は受け付けず、エージェントに検索させる。
      # 指示文（プロンプト）だけでは省略されることが実測で確認されたため、
      # ツール側で構造的に強制する。公式サイトが存在しない場合の逃げ道として
      # 明示的な null は許可する。
      if target_type == "UsesItem" && operation == "create" && !payload.key?("url")
        return { error: "UsesItem の新規作成には url キーが必要です。web_search で「製品名 公式サイト」を検索して" \
                        "公式サイト URL を url に含めてください。公式サイトが存在しない場合のみ url: null を明示してください" }
      end

      pending_change = nil
      ActiveRecord::Base.transaction do
        supersede_replaced!(replaces_pending_change_id)
        pending_change = @chat.pending_changes.create!(
          message: @chat.messages.order(:id).last,
          target_type: target_type,
          operation: operation,
          target_id: target_id,
          payload: payload
        )
      end

      {
        pending_change_id: pending_change.id,
        status: pending_change.status,
        note: "提案を作成しました。画面のプレビューで管理者の承認を待ってください。承認・否認の結果は改めて通知されます。"
      }
    rescue JSON::ParserError
      { error: "payload_json が JSON として解釈できません" }
    rescue ActiveRecord::RecordInvalid => e
      { error: "提案を作成できません: #{e.record.errors.full_messages.join(', ')}" }
    rescue PendingChange::InvalidTransition => e
      { error: "置き換え対象の保留変更を置換できません: #{e.message}" }
    rescue ArgumentError => e
      { error: "引数が不正です: #{e.message}" }
    end

    private

    def supersede_replaced!(replaces_pending_change_id)
      return if replaces_pending_change_id.blank?

      replaced = @chat.pending_changes.find_by(id: replaces_pending_change_id)
      return if replaced.nil?

      replaced.supersede!
    end
  end
end
