# frozen_string_literal: true

module AdrManagement
  # ADR の再評価条件に対する点検結果を記録する。対象は accepted かつ
  # 再評価条件を持つ ADR のみ（それ以外は点検すべき条件が存在しない）。
  # 未来日の点検は「未点検」の判定を実際には点検していない期間まで
  # 抑止してしまうため許可しない。
  class RecordReevaluationCheck < ApplicationAction
    def initialize(adr:, attributes:, origin:)
      @adr = adr
      @attributes = attributes.symbolize_keys
      @origin = origin
    end

    def perform
      if (error = validate_checkable || validate_checked_on)
        return failure(error)
      end

      check = @adr.reevaluation_checks.create!(
        checked_on: @attributes[:checked_on] || Date.current,
        result: @attributes[:result],
        note: @attributes[:note],
        origin: @origin
      )
      success(check)
    rescue ActiveRecord::RecordInvalid => e
      failure(invalid_input_errors(e.record))
    end

    private

    def validate_checkable
      unless @adr.status == "accepted"
        return OperationError.build(
          kind: :check_not_allowed,
          param: "number",
          message: "点検を記録できるのは accepted（承認済み）の ADR のみです" \
                   "（#{@adr.display_number} は #{@adr.status}）",
          next_action: "superseded の場合は置換変遷を辿り、現行の後継 ADR に点検を記録してください"
        )
      end

      if @adr.reevaluation_conditions.blank?
        return OperationError.build(
          kind: :check_not_allowed,
          param: "number",
          message: "ADR #{@adr.display_number} には再評価条件が記録されていないため、点検の対象がありません",
          next_action: "再評価条件を設ける場合は update_adr_tool で reevaluation_conditions を追記してから点検してください"
        )
      end

      nil
    end

    def validate_checked_on
      checked_on = @attributes[:checked_on]
      return nil if checked_on.blank? || checked_on <= Date.current

      OperationError.build(
        kind: :invalid_input,
        param: "checked_on",
        message: "点検日（checked_on）に未来日は指定できません: #{checked_on}",
        next_action: "当日以前の日付を指定するか、省略して当日の点検として記録してください"
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
