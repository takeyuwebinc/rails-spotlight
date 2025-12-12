# frozen_string_literal: true

# month_field から送信される "YYYY-MM" 形式を Date に変換するカスタム型
class MonthDateType < ActiveRecord::Type::Date
  def cast(value)
    return nil if value.blank?

    if value.is_a?(String) && value.match?(/\A\d{4}-\d{2}\z/)
      Date.parse("#{value}-01")
    else
      super
    end
  end
end

ActiveRecord::Type.register(:month_date, MonthDateType)
