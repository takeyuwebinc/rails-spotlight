# frozen_string_literal: true

module AdrManagement
  # ADR の内容・ステータスを更新し、変更前スナップショットを版として記録する。
  # ステータス遷移は proposed→accepted / proposed→rejected / accepted→deprecated
  # のみ許可する。superseded への変更は置換の一体操作（RegisterAdr）のみが行える。
  class UpdateAdr < ApplicationAction
    def initialize(adr:, attributes:, origin:)
      @adr = adr
      @attributes = attributes.symbolize_keys
      @origin = origin
    end

    def perform
      if (error = validate_status_transition)
        return failure(error)
      end

      before = @adr.snapshot_attributes
      ActiveRecord::Base.transaction do
        @adr.update!(@attributes)
        changed = @adr.previous_changes.keys & Adr::SNAPSHOT_ATTRIBUTES
        @adr.record_revision!(
          change_type: "updated",
          origin: @origin,
          before: before,
          changed_fields: changed
        )
      end
      RefreshSearchIndex.perform(adr: @adr)
      success(@adr)
    rescue ActiveRecord::RecordInvalid => e
      failure(invalid_input_errors(e.record))
    end

    private

    def validate_status_transition
      new_status = @attributes[:status]&.to_s
      return nil if new_status.blank? || new_status == @adr.status

      allowed = Adr::ALLOWED_STATUS_TRANSITIONS.fetch(@adr.status, [])
      return nil if allowed.include?(new_status)

      OperationError.build(
        kind: :invalid_status_transition,
        param: "status",
        message: "ステータスを #{@adr.status} から #{new_status} へは変更できません" \
                 "（許可される遷移: proposed→accepted, proposed→rejected, accepted→deprecated。" \
                 "superseded への変更は置換指定付きの登録でのみ行えます）",
        next_action: allowed.any? ? "変更可能なステータス: #{allowed.join(', ')}" : "この ADR のステータスは変更できません。決定を置き換える場合は置換指定付きの登録を使用してください"
      )
    end

    def invalid_input_errors(record)
      record.errors.map do |error|
        OperationError.build(
          kind: :invalid_input,
          param: error.attribute.to_s,
          message: error.full_message,
          next_action: "入力内容を修正して再実行してください"
        )
      end
    end
  end
end
