# frozen_string_literal: true

module WorkHour
  class AvailabilityCalculator
    BASE_HOURS = 160 # 月間基準稼働時間

    def initialize(months_ahead: 3)
      @months_ahead = months_ahead
    end

    def monthly_availability
      @months_ahead.times.map do |i|
        target_month = Date.current.next_month(i).beginning_of_month
        {
          month: target_month,
          month_label: target_month.strftime("%Y年%m月"),
          rate: calculate_rate(target_month)
        }
      end
    end

    def current_rate
      calculate_rate(Date.current.beginning_of_month)
    end

    def next_available_month
      @months_ahead.times do |i|
        target_month = Date.current.next_month(i).beginning_of_month
        rate = calculate_rate(target_month)
        return target_month.strftime("%Y年%m月") if rate < 100
      end
      "#{@months_ahead}ヶ月以降"
    end

    def status
      rate = current_rate
      if rate >= 100
        "満稼働"
      elsif rate >= 80
        "ほぼ満稼働"
      elsif rate >= 50
        "一部受付可"
      else
        "受付可"
      end
    end

    private

    def calculate_rate(target_month)
      total_estimate_hours = ProjectMonthlyEstimate
        .joins(:project)
        .where(year_month: target_month)
        .where(work_hour_projects: { status: "active" })
        .sum(:estimated_hours)

      rate = (total_estimate_hours.to_f / BASE_HOURS * 100).round
      [ rate, 100 ].min
    end
  end
end
