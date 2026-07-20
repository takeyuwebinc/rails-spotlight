# frozen_string_literal: true

module AdrManagement
  # 誤った案件に登録された ADR の所属案件を変更する（誤登録の是正）。
  # 番号は移動先案件の採番カウンタから新しく払い出し、元の番号は欠番として
  # 再利用しない。置換関係は同一案件内で閉じるため、置換関係を持つ ADR の
  # 案件変更はできない。プロジェクトは案件配下の概念のため参照を解除する。
  class ChangeAdrEngagement < ApplicationAction
    def initialize(adr:, engagement:, origin:)
      @adr = adr
      @engagement = engagement
      @origin = origin
    end

    def perform
      if @adr.supersession_involved?
        return failure(OperationError.build(
          kind: :invalid_input,
          param: "engagement",
          message: "置換関係を持つ ADR の所属案件は変更できません（置換関係は同一案件内で閉じるため）",
          next_action: "置換関係の整理が必要な場合は個別に相談してください"
        ))
      end
      return success(@adr) if @engagement.id == @adr.engagement_id

      before = @adr.snapshot_attributes
      ActiveRecord::Base.transaction do
        @adr.update!(
          engagement: @engagement,
          number: @engagement.issue_next_number!,
          project: nil
        )
        @adr.record_revision!(
          change_type: "engagement_changed",
          origin: @origin,
          before: before,
          changed_fields: %w[engagement_id number project_id]
        )
      end
      # 検索インデックスの再構築は不要: チャンクの内容は本文のみに依存し、
      # 案件による絞り込みは検索時に ADR 本体を JOIN して解決するため
      success(@adr)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages)
    end
  end
end
