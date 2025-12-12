# frozen_string_literal: true

module WorkHour
  class ProjectMonthlyEstimate < ApplicationRecord
    belongs_to :project, class_name: "WorkHour::Project"

    validates :year_month, presence: true, uniqueness: { scope: :project_id }
    validates :estimated_hours, presence: true, numericality: { greater_than_or_equal_to: 0 }

    # month_fieldから送信される "YYYY-MM" 形式を Date に変換
    attribute :year_month, :month_date

    scope :for_month, ->(year_month) { where(year_month: year_month.beginning_of_month) }

    def self.total_hours_for_month(year_month)
      for_month(year_month).sum(:estimated_hours)
    end
  end
end
