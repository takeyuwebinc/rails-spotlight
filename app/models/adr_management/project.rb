# frozen_string_literal: true

module AdrManagement
  # 案件内の期間（開始・終了）を持つ開発単位（例: Fabble保守開発2026年度）。
  # 工数管理ドメインの WorkHour::Project とは別モデル。
  class Project < ApplicationRecord
    belongs_to :engagement, class_name: "AdrManagement::Engagement"
    has_many :adrs, class_name: "AdrManagement::Adr",
      foreign_key: :project_id, dependent: :restrict_with_error

    validates :name, presence: true
    validate :end_date_not_before_start_date

    private

    def end_date_not_before_start_date
      return if start_date.blank? || end_date.blank? || end_date >= start_date

      errors.add(:end_date, :greater_than_or_equal_to, count: start_date)
    end
  end
end
