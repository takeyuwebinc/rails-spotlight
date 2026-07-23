# frozen_string_literal: true

module AdrManagement
  # ADR 検索の取り逃がし報告を記録する。到達できた ADR の指定は任意で、
  # 「存在するはずだが見つけられなかった」報告（adr なし）も受け付ける。
  class ReportSearchMiss < ApplicationAction
    def initialize(query:, note:, origin:, adr: nil)
      @query = query
      @note = note
      @origin = origin
      @adr = adr
    end

    def perform
      report = SearchMissReport.create!(
        query: @query,
        note: @note,
        adr: @adr,
        origin: @origin
      )
      success(report)
    rescue ActiveRecord::RecordInvalid => e
      failure(invalid_input_errors(e.record))
    end

    private

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
