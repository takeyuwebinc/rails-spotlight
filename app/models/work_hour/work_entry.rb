# frozen_string_literal: true

module WorkHour
  class WorkEntry < ApplicationRecord
    belongs_to :project, class_name: "WorkHour::Project", optional: true

    validates :worked_on, presence: true
    validates :target_month, presence: true
    validates :minutes, presence: true, numericality: { only_integer: true, greater_than: 0 }

    scope :for_month, ->(year_month) { where(target_month: year_month.beginning_of_month) }
    scope :for_date, ->(date) { where(worked_on: date) }
    scope :for_period, ->(start_month, end_month) {
      where(target_month: start_month.beginning_of_month..end_month.beginning_of_month)
    }

    def hours
      minutes.to_f / 60
    end

    def project_name
      project&.name || "その他"
    end

    def project_code
      project&.code || ""
    end
  end
end
