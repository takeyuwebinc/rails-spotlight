# frozen_string_literal: true

module AdrManagement
  # ADR を案件に登録する。置換対象の指定がある場合は、新 ADR の登録・
  # 旧 ADR のステータス「superseded」への変更・置換関係の記録を
  # 1つのトランザクションで行う（置換の一体操作）。旧 ADR の更新漏れによる
  # 「矛盾する承認済み ADR の並存」を防ぐため、部分的な成功は残さない。
  class RegisterAdr < ApplicationAction
    # 採番カウンタの同時払い出しが衝突した場合の再試行回数
    NUMBERING_RETRIES = 3

    def initialize(engagement:, attributes:, origin:, superseded_numbers: [])
      @engagement = engagement
      @attributes = attributes.symbolize_keys
      @origin = origin
      @superseded_numbers = Array(superseded_numbers)
    end

    # 登録時に指定できる初期ステータス。rejected/deprecated/superseded は
    # 既存の決定の状態遷移によってのみ到達する
    INITIAL_STATUSES = %w[proposed accepted].freeze

    def perform
      if (error = validate_initial_status)
        return failure(error)
      end

      superseded_adrs = find_superseded_adrs
      if (error = validate_supersession(superseded_adrs))
        return failure(error)
      end

      adr = register_with_numbering_retry(superseded_adrs)
      RefreshSearchIndex.perform(adr: adr)
      success(adr)
    rescue ActiveRecord::RecordInvalid => e
      failure(invalid_input_errors(e.record))
    end

    private

    def validate_initial_status
      status = @attributes[:status]&.to_s
      return nil if status.blank? || INITIAL_STATUSES.include?(status)

      OperationError.build(
        kind: :invalid_input,
        param: "status",
        message: "登録時のステータスは proposed（提案中）または accepted（承認済み）のみ指定できます",
        next_action: "過去に下した決定の記録なら accepted、これからの提案なら proposed を指定してください"
      )
    end

    def find_superseded_adrs
      @superseded_numbers.map do |number|
        @engagement.adrs.find_by(number: number) || number
      end
    end

    def validate_supersession(superseded_adrs)
      return nil if superseded_adrs.empty?

      missing = superseded_adrs.reject { |adr| adr.is_a?(Adr) }
      if missing.any?
        return OperationError.build(
          kind: :invalid_supersession,
          param: "superseded_numbers",
          message: "置換対象の ADR（番号: #{missing.join(', ')}）が案件「#{@engagement.code}」に存在しません",
          next_action: "ADR 検索・参照で対象案件の ADR 番号を確認してください"
        )
      end

      not_accepted = superseded_adrs.reject { |adr| adr.status == "accepted" }
      if not_accepted.any?
        return OperationError.build(
          kind: :invalid_supersession,
          param: "superseded_numbers",
          message: "置換対象にできるのは「accepted（承認済み）」の ADR のみです" \
                   "（番号: #{not_accepted.map(&:number).join(', ')} は対象外）",
          next_action: "置換対象のステータスを確認してください。既に superseded の場合は、その後継 ADR を置換対象にしてください"
        )
      end

      if @attributes[:status].present? && @attributes[:status] != "accepted"
        return OperationError.build(
          kind: :invalid_supersession,
          param: "status",
          message: "置換指定時の新 ADR の初期ステータスは「accepted（承認済み）」のみ指定できます" \
                   "（却下時に旧 ADR が後継なしの「superseded」のまま残ることを防ぐため）",
          next_action: "status を accepted にするか、置換指定なしで提案として登録してください"
        )
      end

      nil
    end

    def register_with_numbering_retry(superseded_adrs)
      attempts = 0
      begin
        register(superseded_adrs)
      rescue ActiveRecord::RecordNotUnique
        attempts += 1
        retry if attempts < NUMBERING_RETRIES
        raise
      end
    end

    def register(superseded_adrs)
      ActiveRecord::Base.transaction do
        status = superseded_adrs.any? ? "accepted" : @attributes[:status]
        adr = @engagement.adrs.create!(
          @attributes.merge(
            number: @engagement.issue_next_number!,
            status: status
          )
        )
        adr.record_revision!(change_type: "created", origin: @origin)

        superseded_adrs.each do |superseded|
          before = superseded.snapshot_attributes
          superseded.update!(status: "superseded")
          superseded.record_revision!(
            change_type: "status_changed",
            origin: @origin,
            before: before,
            changed_fields: %w[status]
          )
          Supersession.create!(superseding_adr: adr, superseded_adr: superseded)
        end

        adr
      end
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
