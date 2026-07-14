# frozen_string_literal: true

module WorkHour
  # 案件の予算工数（時間）と実績（分）から、実績時間・消化率・消化状態を算出する値オブジェクト。
  # Project にも WorkEntry にも依存せず、プリミティブのみを受け取る。
  class BudgetConsumption
    CAUTION_RATE = 90  # この消化率以上を「注意」とする
    OVER_RATE = 100    # この消化率を超えたら「超過」とする

    attr_reader :budget_hours, :actual_minutes

    def initialize(budget_hours:, actual_minutes:)
      @budget_hours = budget_hours
      @actual_minutes = actual_minutes.to_i
    end

    def actual_hours
      actual_minutes / 60.0
    end

    # 予算が未登録なら消化率は算出不能。
    # 100% を超えても上限でキャップしない。予算管理は超過の検知が目的であり、
    # 超過幅そのものが判断材料になるため。
    def rate
      return nil if budget_hours.nil?

      (actual_hours / budget_hours.to_f * 100).round
    end

    def status
      return nil if rate.nil?

      if rate > OVER_RATE
        :over
      elsif rate >= CAUTION_RATE
        :caution
      else
        :normal
      end
    end

    def over?
      status == :over
    end

    def caution?
      status == :caution
    end
  end
end
